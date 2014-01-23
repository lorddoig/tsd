#!/usr/bin/env perl

# tsd
#   config
#       - ~/.tsd_rc exists? Overwrite?
#       - Prompt for location
#       - Write to tsd_rc
#   init
#       - .tsd exists? Exit.
#       - Prompt for proj-specific dir
#       - Write to local config
#   install
#
#   search

use feature qw(switch);
use File::Path::Expand;
use File::Path qw(mkpath);
use File::Find;
use File::Spec;
use Cwd qw(realpath getcwd);
use File::chdir;
use File::Basename;
use File::Copy;
use File::Util qw( SL );

my $prog_name = 'tsd';
my $project_config_filename = 'TSDFile';
my $defs_path;
my $local_defs_path;
my $project_dir = getcwd();
my $global_config_file = expand_filename("~/.tsd_rc");

# ================
# Errors
# ================

my %errors;
my %warnings;
$errors{'noGlobalConf'} = "There is no global configuration file.\nPlease run \`$prog_name config\`\n";
$warnings{'globalConfOverwrite'} = "Global configuration exists.\nOverwrite? (yes/no): ";

sub throw{
    print "${\uc($_[0])}: ";
    print eval("\$${\lc($_[0])}s{'$_[1]'}");
    exit 1 if($_[0] =~ /error/u);
}

sub getAffirmativeResponse{
    chomp(local $response = <STDIN>);
    if ($response !~ /y(es)?/) { print "Aborting.\n"; exit 1; }
}

# ================
# Usage
# ================

sub usage{
    print "TSD - A TypeScript 'dependency' manager\n\n";
    print "Usage: $prog_name <command> [args]\n\n";
    print "Where command is one of:\n";
    print "install [package]   Installs a dependency into the local project\n";
    print "search  [package]   Searches the definitions repositories for matching packages\n";
    print "add     [repo]      Add the given repo to the available sources.\n";
    print "                    [repo] should be a git URI.\n";
    print "config              Set up global configuration (definition storage location etc)\n";
    print "init                Initialize the current directory as a project requiring TS dependencies.\n";

    exit 1;
}

# ================
# Global conf
# ================


sub checkGlobalConfigExists{
    if (! -e $global_config_file) {
        if ($_[0]) {
            return 0;
        } else {
            &throw('error', 'noGlobalConf');
        }
    } else {
        return 1;
    }
}

sub initGlobalConf{
    if (&checkGlobalConfigExists(1)) {
        &throw('warning', 'globalConfOverwrite');
        &getAffirmativeResponse();
    }

    print "\n";
    print "Where would you like to store global definitions repos?\n";
    print "Default is ~/.tsd/\n";
    print "> ";
    chomp(local $defs_dir = <STDIN>);
    $defs_dir = '~/.tsd' if(! $defs_dir);
    $defs_dir = File::Spec->rel2abs(expand_filename("$defs_dir\/definitions"));

    if (! -e $defs_dir) {
        print "\n";
        print "$defs_dir does not exist.  Create? (yes/no): ";
        &getAffirmativeResponse();
    } elsif (-e $defs_dir && ! -d $defs_dir) {
        print "\n";
        print "Location exists, but is not a directory.\n";
        print "Aborting.\n";
        exit 1;
    } 

    print "Making $defs_dir\n";
    mkpath($defs_dir);

    print "Storing definitions in $defs_dir\n";
    open(G_CONF, ">$global_config_file");
    print G_CONF "defs_path=$defs_dir";
    close(G_CONF);
}

sub getDefsPath{
    open(G_CONF, $global_config_file);
    while (<G_CONF>) {
        $defs_path = $1 if($_ =~ /^defs_path=(.*)$/)
    }
    close(G_CONF);
}

# ================
# Search
# ================

my @search_files;

sub searchTSD{
    &checkGlobalConfigExists();
    &getDefsPath();
    &checkForRepoUpdates();
    &usage if($_[0] !~ /[a-z]+/);

    if (!$defs_path || ! -e $defs_path) {
        print "Error, cannot find global definitions. $defs_path does not exist.\n";
        exit 1;
    }

    finddepth(\&processSearchFile, $defs_path);
    
    local @matches;
    foreach(@search_files) {
        # Fuzzy match search with filenames
        if($_ =~ /.*$_[0].*\.d\.ts$/) {
            push @matches, $_;
        }
    }

    # Exit uncerimoniously if there are no results
    exit 1 if(scalar @matches == 0);

    print "\n";
    local $count = 1;
    local %matches = ();

    # Store matches in hash with incrementing numbers as keys, so as to allow
    # selection by number for installation.
    foreach(@matches) {
        print "($count) ${\&prettifyPath($_)}\n";
        $matches{ "$count" } = $_;
        $count++;
    }

    # Return the matches for being called by installTSD()
    return %matches;
}

sub checkForRepoUpdates{
    return if(int(rand(10)) != 5);
    local @repos = glob("$defs_path/**");
    foreach(@repos) { 
       if(-d $_) {
            local $CWD = $_;
            local $gitstat = `git remote update && git status uno`;
            if ($gitstat =~ /Your branch is behind/) {
                local $repo_name = pop(split('/', $_));
                print "Updates are available for the $repo_name definitions repository.\n";
                print "You can manage this by navigating to $defs_path and manipulating the git repository directly.\n\n";
            }
        }
    }
}

sub processSearchFile{

    # Cut $defs_path from the path for display purposes
    local $name = $File::Find::name =~ s/$defs_path\/?//r;

    # Don't return directories
    if (! -d $File::Find::name) {
        push @search_files, $name;
    }
}

# ================
# Install
# ================

sub checkLocalConfigExists{
    if (! -e $project_config_filename) {
        print "No TSDFile found.  Please run \`$prog_name init\`.\n";
        exit 1;
    }
}

sub getLocalConfig{
    open(L_CONF, "TSDFile");
    while (<L_CONF>) {
        $local_defs_path = $1 if($_ =~ /^defs_path=(.*)$/);
    }
    close(L_CONF);
}

sub initLocalConfig{
    if (-e $project_config_filename) {
        print "Project already initialized.  Please delete your TSDFile to reinitialize.\n";
        exit 1;
    }

    print "Where would you like to store definitions for this project?\n";
    print "The path should be relative to the current directory.\n";
    print "Default is ./ts-definitions.\n";
    print "> ";
    chomp(local $dir = <STDIN>);
    $dir = 'ts-definitions' if(!$dir);
    if (-e realpath($dir) && ! -d realpath($dir)) {
        print "\n\nERROR: Path given exists, but is not a directory.\n";
        exit 1;
    } elsif (-d realpath($dir)) {
        print "\n\nWARNING: Directory exists.  Continue? (y/n): ";
        &getAffirmativeResponse();
    }

    local $default_local_conf = "defs_path=$dir";
    open(L_CONF, '>TSDFile');
    print L_CONF $default_local_conf;
    close(L_CONF);
}

sub installTSD{
    &checkLocalConfigExists();
    &getLocalConfig();

    # Search for install term
    local %matches = &searchTSD($_[0]);
    local $choice;

    # If there's only one result, go ahead and install that
    $choice = 1 if(scalar(keys(%matches)) == 1);

    # Otherwise continue to prompt until a valid numeric response is received
    while (!$matches{ $choice }) {
        $choice = &promptDefChoice(scalar(keys(%matches)));
    }

    print "\n";
    print "Resolving dependencies...\n\n";
    local @deps = &findDependencies($matches{ $choice });
    local @canon_deps;

    # Put the install candidate in first place
    push(@canon_deps, realpath("$defs_path\/$matches{ $choice }"));

    # Get the real parent path of the chosen install candidate
    local $ts_cwd = getTSCwd("$defs_path\/$matches{ $choice }");
    if (!$ts_cwd) {
        print "Could not resolve dependencies.\n";
        exit 1;
    }

    # Set the working directory to the parent folder of install candidate
    local $CWD = $ts_cwd;

    # @deps are generally relative paths, realpath returns the actual path, relative to the $CWD
    # Append said paths to list of dependencies.
    foreach(@deps) {
        if (! -f realpath($_)) {
            print "$matches{ $choice } depends on ${\realpath($_)}, which was not found.\n";
            exit 1;
        }
        push(@canon_deps, realpath($_));
    }

    print "Installing...\n\n";
    foreach(@canon_deps) {
        # Set the working dir to project dir (execution dir)
        local $CWD = "$project_dir\/$local_defs_path";
        # Strip off the absolute part of the path
        local $path = $_ =~ s/$defs_path\/?//r;

        # Make the local directory structure
        mkpath(dirname($path));

        # Copy the dependency to the local project
        copy($_, $path);
    }

    #Print out what just happened
    &printTree(@canon_deps);
}

sub printTree{
    local $CWD = $defs_path;
    foreach(@_) { print "Installed: $local_defs_path\/$1\n" if(realpath($_) =~ /$CWD\/?(.*)/); }
}

sub getTSCwd{
    if ($_[0] =~ /(.*)\/.*\.ts$/ && -d $1) {
        return $1;
    } else {
        return;
    }
}

sub promptDefChoice{
    print "\nPlease choose which definition to install (1 - $_[0]): ";
    chomp(local $choice = <STDIN>);
    return $choice;
}

sub findDependencies{
    local $file = $_[0];
    local @deps;
    open(TS_FILE, "$defs_path\/$file") or die();
    while (<TS_FILE>) {
        push(@deps, $1) if($_ =~ /^\/\/\/\s*<\s*reference\s+path="(.*)"\s+\/\s*>\s*$/);
    }
    return @deps;
}

sub prettifyPath{
    return $_[0] =~ s/\// -> /gr || $_[0];
}

# ================
# Add
# ================

sub addRepo{
    &checkGlobalConfigExists();
    &getDefsPath();
    local $CWD = $defs_path;
    `git clone $_[0]`;
}

# ================
# Runtime
# ================

given($ARGV[0]){
    when("config") { &initGlobalConf() }
    when("search") { &searchTSD($ARGV[1]) }
    when("install") { &installTSD($ARGV[1]) }
    when("init") { &initLocalConfig() }
    when("add") { &addRepo($ARGV[1]) }
    default { &usage() }
}
