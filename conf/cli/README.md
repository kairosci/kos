# cliconf

Native CLI helper installer for omaconf terminal stack.

## Overview

cliconf installs helper command with English cheatsheet per tool in the stack. Tools with built in help stay referenced with never duplicated text. All operations run in user scope with native Bash and standard Unix tools.

## Installation

Run in user scope:

```bash
bash conf/cli/install.sh
```

## Architecture

Installer copies data helpers into the shared omaconf path and registers a marked source block in bashrc idempotently. Helpers cover the retained command line tools. Retired application helpers are removed during setup; graphical applications use their native help.
