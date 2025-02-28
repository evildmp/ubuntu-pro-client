# How to enable Expanded Security Maintenance for Infrastructure (`esm-infra`)

For Ubuntu LTS releases, `esm-infra` will be automatically enabled after
attaching the Ubuntu Pro Client to your account. After `ubuntu-advantage-tools`
is installed and your machine is attached, `esm-infra` should be enabled. If
`esm-infra` is not enabled, you can enable it with the following command:

```console
$ sudo pro enable esm-infra
```

With the `esm-infra` repository enabled, especially on Ubuntu 14.04 and 16.04,
you may see a number of additional package updates available that were not
available previously.

Even if your system had indicated that it was up to date before installing the
`ubuntu-advantage-tools` and attaching, make sure to check for new package
updates after `esm-infra` is enabled using `apt upgrade`. If you have cron jobs
set to install updates, or other unattended upgrades configured, be aware that
this will likely result in a number of package updates with the `esm-infra`
content.

Running `apt upgrade` will now apply all available package updates, including
the ones in `esm-infra`.

```console
$ sudo apt upgrade
```

```{seealso}
For more information, see https://ubuntu.com/security/esm
```
