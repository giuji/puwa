puwa is a little racket script i wrote to manage my dotfiles across machines
that need slightly different versions of the same configuration files. puwa
renders the contents of `./dots` into the home directory, everything between
`{{{...}}}` is considered a token. Values for tokens are defined in
`./host-config/<current_hostname>.rkt` using racket `define` expressions. A
different config file can be specified with `-c <hostname>`.

the name puwa comes from an [uncommon toki pona word](https://sona.pona.la/wiki/puwa)

check [my dotfiles](https://github.com/giuji/dots) to see puwa in action

