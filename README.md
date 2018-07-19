# dfdl - Dwarf Fortress Starter Pack generator for Mac

I decided that using the Windows starter pack on Mac, through Wineskin, instead
of an actual Mac release of DF was just too much. I repeated the process of
downloading and extracting things in the right place Too Many Times, so I wrote
this script.

It downloads various packages and puts them together. It currently filters the
available Mac downloads for the following packages, and lets the user choose a
version for each:

- Dwarf Fortress: http://bay12games.com/dwarves/older_versions.html
- PyLNP: https://bitbucket.org/Pidgeot/python-lnp/downloads/
- PeridexisErrant's Starter Pack, for the graphics: http://dffd.bay12games.com/file.php?id=7622
- DFHack: https://github.com/DFHack/dfhack/releases
- TWBT: https://github.com/mifki/df-twbt/releases

It generates a 'df' folder with everything in the right place. I rename
PyLNP.app to 'Dwarf Fortress LNP.app' because that's the way it works better
with my own Mac launcher, and I additionally create an AppleScript-based app
for running dfhack directly, without the LNP, which just uses the options
that were used by the LNP the last time.

The script relies on HTML scrapping and name matching for most packages, which
could break at any moment.

For GitHub repos, rate limiting for unauthenticated requests hits pretty
quickly, so I made it work with a personal access token. You should create an
account and add a token at https://github.com/settings/tokens. Then,
copy config.yml.example to config.yml and enter the token there.

I'm currently using PeridexisErrant's Starter Pack only for its collection of
graphic packs, I may change this to actually retrieve them from their source.

I am _not_ retrieving any utilities at the moment. In the future I expect to
download all utilities currently provided by PE's starter pack that have a
Mac version.

## Dependencies

The script depends on the curl, unzip, tar and bzip2 system utilities, and
the Nokogiri Ruby library, which is currently handled by Bundler.

For installing it, you need to run

```
bundle install
```

## Running

You start the script by running

```
bundle exec dfdl.rb
```

It will provide a list for different versions of each package, you
choose one by entering its number and pressing enter.

I'm currently using the latest 64 bit versions of all packages, which
works perfectly on my High Sierra installation.
