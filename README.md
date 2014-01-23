# TSD

A TypeScript 'dependency' manager...written in Perl...

## Installation

### \*nix and OS X

Download the `tsd` executable and put it in your PATH.

### Windows

I have no idea.  It probably won't work.

## Usage

After installation, run 

```
tsd config
```

This sets up where definitions (.d.ts files) are stored globally.  Then, inside your TypeScript project, run

```
tsd init
```

which sets up where the definitions will be installed to for the project.  Finally you have to add repositories in which definitions can be found.  Any repository which stores definitions in subdirectories like [DefinitelyTyped](https://github.com/borisyankov/DefinitelyTyped) will do.  The URI can be anything that git understands.

```
tsd add https://github.com/borisyankov/DefinitelyTyped.git
```

This clones the repo into the global storage directory configured in `tsd config`.

### Searching

```
tsd search node

(1) DefinitelyTyped -> msnodesql -> msnodesql.d.ts
(2) DefinitelyTyped -> node -> node-0.8.8.d.ts
(3) DefinitelyTyped -> node -> node.d.ts
(4) DefinitelyTyped -> node-azure -> azure.d.ts
(5) DefinitelyTyped -> node-ffi -> node-ffi.d.ts
(6) DefinitelyTyped -> node-fibers -> node-fibers.d.ts
(7) DefinitelyTyped -> node-git -> node-git.d.ts
(8) DefinitelyTyped -> node_redis -> node_redis.d.ts
(9) DefinitelyTyped -> node_zeromq -> zmq.d.ts
(10) DefinitelyTyped -> nodemailer -> nodemailer.d.ts
(11) DefinitelyTyped -> simple-cw-node -> simple-cw-node.d.ts
```

### Installing

```
tsd install node

(1) DefinitelyTyped -> msnodesql -> msnodesql.d.ts
(2) DefinitelyTyped -> node -> node-0.8.8.d.ts
(3) DefinitelyTyped -> node -> node.d.ts
(4) DefinitelyTyped -> node-azure -> azure.d.ts
(5) DefinitelyTyped -> node-ffi -> node-ffi.d.ts
(6) DefinitelyTyped -> node-fibers -> node-fibers.d.ts
(7) DefinitelyTyped -> node-git -> node-git.d.ts
(8) DefinitelyTyped -> node_redis -> node_redis.d.ts
(9) DefinitelyTyped -> node_zeromq -> zmq.d.ts
(10) DefinitelyTyped -> nodemailer -> nodemailer.d.ts
(11) DefinitelyTyped -> simple-cw-node -> simple-cw-node.d.ts

Please choose which definition to install (1 - 11): 3

Resolving dependencies...

Installing...

Installed: ts-definitions/DefinitelyTyped/node/node.d.ts
```

Dependencies in the installed script are resolved and automatically installed too.  The scripts are copied to the project directory set up in `tsd init`.  In this case, the `node.d.ts` script can be referenced in the your TypeScript files like so (assuming the default project directory `ts-definitions` was chosen):

```
/// <reference path="ts-definitions/DefinitelyTyped/node/node.d.ts" />
```

### Uninstalling

Is by hand at the moment.  Just delete the files from the local project.

### Updating repos

Every so often (when `int(rand(10)) == 5`, to be precise) the `search` and `install` commands will check if any of the definitions repos have upstream changes, and will helpfully whine at you if so.  For now you need to into said directory and manipulate the git repo by hand.

## Help

### Why Perl?!

* Because writing CLI utilities in JavaScript isn't nice.
* Because writing this in Ruby would have caused users to deal with its dependency hell.
* Because writing this in Python would have required learning Python.
* Because writing this in Bash was tried, and it was horrible.
* Because writing this Java/C/C++/Rust/D/Erlang/Scheme/APL/Lua/Forth would have made my head explode.

### This code is AWFUL

Probably.  I wrote this in a day having never written a line of Perl before in my life.

It works\* though.

---

* For me, anyway.

## Contributing

Please god yes.

### Roadmap

* Uninstallation of definitions
* Listing of dependencies in local TSDFile to allow an `npm install`-esque experience
* Support of git references for individual definitions, not just what's in the working copy

## License

* Modifications made for redistribution must be made whilst listening to a single Enya song (of your choosing) on repeat.

Otherwise, do what you want.
