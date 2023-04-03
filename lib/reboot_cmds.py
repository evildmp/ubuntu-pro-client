#!/usr/bin/env python3

"""
Run configuration operations during system boot.

Some uaclient operations cannot be fully completed by running a single
command. For example, when upgrading uaclient from trusty to xenial,
we may have a livepatch change in the contract, allowing livepatch to be
enabled on xenial. However, during the upgrade we cannot install livepatch on
the system because the running kernel version will not be updated until reboot.

Pro client touches a flag file
/var/lib/ubuntu-advantage/marker-reboot-cmds-required to indicate this script
should run at next boot to process any pending/unresovled config operations.
"""

import logging
import sys

from uaclient import (
    config,
    contract,
    defaults,
    exceptions,
    lock,
    messages,
    upgrade_lts_contract,
)
from uaclient.cli import setup_logging
from uaclient.entitlements.entitlement_status import ApplicationStatus
from uaclient.entitlements.fips import FIPSEntitlement
from uaclient.files import notices, state_files

# Retry sleep backoff algorithm if lock is held.
# Lock may be held by auto-attach on systems with ubuntu-advantage-pro.
SLEEP_ON_LOCK_HELD = 1
MAX_RETRIES_ON_LOCK_HELD = 7


def fix_pro_pkg_holds(cfg: config.UAConfig):
    fips = FIPSEntitlement(cfg)
    fips_status, _ = fips.application_status()
    if fips_status != ApplicationStatus.ENABLED:
        return
    logging.debug("Attempting to remove Ubuntu Pro FIPS package holds")
    try:
        fips.setup_apt_config()  # Removes package holds
        logging.debug("Successfully removed Ubuntu Pro FIPS package holds")
    except Exception as e:
        logging.error(e)
        logging.warning("Could not remove Ubuntu Pro FIPS package holds")
    try:
        fips.install_packages(cleanup_on_failure=False)
    except exceptions.UserFacingError as e:
        logging.error(e.msg)
        logging.warning(
            "Failed to install packages at boot: {}".format(
                ", ".join(fips.packages)
            )
        )
        sys.exit(1)


def refresh_contract(cfg: config.UAConfig):
    try:
        contract.request_updated_contract(cfg)
    except exceptions.UrlError as exc:
        logging.exception(exc)
        logging.warning(messages.REFRESH_CONTRACT_FAILURE)
        sys.exit(1)


def process_remaining_deltas(cfg: config.UAConfig):
    upgrade_lts_contract.process_contract_delta_after_apt_lock(cfg)


def process_reboot_operations(cfg: config.UAConfig):
    if not cfg.is_attached:
        logging.debug("Skipping reboot_cmds. Machine is unattached")
        state_files.reboot_cmd_marker_file.delete()
        return

    if state_files.reboot_cmd_marker_file.is_present:
        logging.debug("Running process contract deltas on reboot ...")

        try:
            fix_pro_pkg_holds(cfg)
            refresh_contract(cfg)
            process_remaining_deltas(cfg)

            state_files.reboot_cmd_marker_file.delete()
            notices.remove(notices.Notice.REBOOT_SCRIPT_FAILED)
            logging.debug("Successfully ran all commands on reboot.")
        except Exception as e:
            msg = "Failed running commands on reboot."
            msg += str(e)
            logging.error(msg)
            notices.add(notices.Notice.REBOOT_SCRIPT_FAILED)


def main(cfg: config.UAConfig):
    """Retry running process_reboot_operations on LockHeldError

    :raises: LockHeldError when lock still held by auto-attach after retries.
             UserFacingError for all other errors
    """
    try:
        with lock.SpinLock(
            cfg=cfg,
            lock_holder="ua-reboot-cmds",
            sleep_time=SLEEP_ON_LOCK_HELD,
            max_retries=MAX_RETRIES_ON_LOCK_HELD,
        ):
            process_reboot_operations(cfg=cfg)
    except exceptions.LockHeldError as e:
        logging.warning("Lock not released. %s", str(e.msg))
        sys.exit(1)


if __name__ == "__main__":
    setup_logging(
        logging.INFO,
        logging.DEBUG,
        defaults.CONFIG_DEFAULTS["log_file"],
    )
    cfg = config.UAConfig()
    setup_logging(logging.INFO, logging.DEBUG, log_file=cfg.log_file)
    main(cfg=cfg)
