Local testing repository manager
================================

`wbrepo` script creates a local Aptly repository (separated from system defaults, it uses its own configuration file and directory in user's home dir) and provides tools to manage it.


Requirements
------------

* aptly
* gpg


Features
--------

`wbrepo` script is pretty minimalistic. It allows things such:

* add packages to local repository
* remove packages from local repository using Aptly queries (aka reprepro queries)
* list all packages in local repository
* provide an HTTP access to this repository (on port 8086 by default). A GPG public key is available at http://localhost:8086/repo.gpg.key

This script automates:

* Aptly commands
* GPG key generating


Usage examples
--------------

Add bunch of .deb files into repository:
```
$ wbrepo add pkg1.deb pkg2.deb ../pkg3.deb # manual list of debs
$ wbrepo add ./packages/ # directory contains deb files also supported
```

List all packages in repository
```
$ wbrepo list
```

Remove packages from repository
```
$ wbrepo remove python-wb-common # remove specific package
$ wbrepo remove 'Name (~ .*-dev)' # remove all development packages
$ wbrepo remove 'Name (% *)' # remove all packages
```

Start HTTP server with repository (Ctrl^C to stop)
```
$ wbrepo serve
$ wbrepo serve 9092 # start server on port 9092
```
