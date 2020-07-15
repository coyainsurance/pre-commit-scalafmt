# Scalafmt hook for pre-commit

## Overview

This is [pre-commit](https://pre-commit.com/) hook that runs [scalafmt](scalameta.org/scalafmt/)
on changed `.scala` and `.sbt` files each time you commit them.

## Getting Started

You need to have [pre-commit](https://pre-commit.com/),
[Nailgun](https://github.com/facebook/nailgun#readme) (for installation
guidelines please see the respective sites) and Bash installed first.

Next, you should place the hook inside the `.pre-commit-hooks.yaml`. Minimal version can looks like this:
```
- repo: git@github.com:coyainsurance/pre-commit-scalafmt.git
  sha: master # you probably do not want to use latest version, but rather pin it to specific commit and update manually
  hooks:
  - id: scalafmt
    args: [ -p9090, -t ] # run in server mode on port 9090 and pass `--test` to scalafmt; alternatively you can place here other supported cmdline arguments
```

After that, you should run
```
pre-commit install -f --install-hooks
```
or equivalent to install and/or update your hooks file.

Then you should be ready to enjoy automatic checks if your Scala files are formatted accordingly.

## Details

Script has several options than can be passed using `args` array for the `pre-commit` hook configuration.

- `-c $scalafmtConfig` sets the scalafmt config (default=`.scalafmt.conf`).

- `-d $bootstrapDirectory` sets the bootstrap directory (default=`$HOME/.scalafmt`).

  It is used to place `coursier` and `scalafmt` binaries for the first time this hook is run.  

- `-p $port` - binds `nailgun` to the specified port. Implies the `-s` option.

- `-s` - starts `scalafmt` in background using `nailgun`.

  That should significantly speedup checking your files, as `scalafmt` is then already running in background
  and JVM processes can take quite significant time to initialize.
  The tradeoff is that you may sometimes need to commit again, as hook may fail due to connection problems
  (apparently happens with long-enough running `nailgun` service).

  You should also make sure to have recent enough `nailgun` version (`0.9.1` should do).
  In case of older version you may simply get no response back.

  Default port is specified by `$NAILGUN_PORT` environment variable if it exists. If not, `2113` is taken.
  Alternatively one can use `-p` option to override the port.

- `-S` allows you to set the Scala version for `scalafmt`, e.g. `-S2.12` or `-S2.13`.

- `-t` - passes `--test` to `scalafmt`, that implies no mis-formatted file will be changed instead of returning `1` exit code on any.

- `-v $version` - forces to use specific (default=`1.4.0`) `scalafmt` version. **Note**: `1.4.0` is a significantly old version. Make sure to match this with the version you are using, e.g. `2.6.3`.

- `-o $organisation` - forces to use specific (default=`com.geirsson`) `scalafmt` organisation. **Note**: if you are using a recent version (>= released 2.0) of `scalafmt`, you will want to set the organisation to `org.scalameta`.

It was successfully tested both on Linux distributions and MacOS.
