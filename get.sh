#!/bin/bash

#================================================#
#                                                #
#    DOCUMENTATION CONVERTER FOR LUA MANUALS     #
#   Copyright  (c) 2022 - Thadeu A C de Paula    #
#                                                #
#     This software is free under the terms      #
# of the GNU General Public License - version 3  #
# as published in  https://www.gnu.org/licenses. #
#                                                #
#================================================#

#| This script is used to retrieve the official Lua
#| source code and convert its html documentation
#| in plain text markdown
#|
#| To run this script these tools are needed:
#| - curl
#| - GNU sed
#| - bash
#| - tar
#| - gzip
#| - uniq

download_src() {
  if [[ ! -d "src" ]]; then
    mkdir src
    for src in \
      https://www.lua.org/ftp/lua-5.4.4.tar.gz \
      https://www.lua.org/ftp/lua-5.3.6.tar.gz \
      https://www.lua.org/ftp/lua-5.2.4.tar.gz \
      https://www.lua.org/ftp/lua-5.1.5.tar.gz
    do
      curl "$src" | tar xvz -C src --;
    done
  fi
}

process_manual() {
  local infile="$1"
  local index="$2"
  local outfile="$3"

  sed  '

    # Tag names in lowercase
    s!<\([^a-z]\+\)\?\([a-z]\+\)!<\1\L\2!gI

    # Separate lines until <body> and from </body> them cut document edges
    s!<body\(\s[^>]\+\)\?>!<body>\n!g
    s!</body\s*>!\n</body>!g
    1,/<body>/d; /<\/body>/,$d

    # Discarded tags
    s!<\/\?\(div\|article\|section\|nav\|header\|footer\)\(\s\+[^>]\+\)\?>!!gI

    # Group formatting under same tag to check nesting below...
    s!<\(/\)\?\(i\|ins\|mark\)\(\s[^>]*\)\?>!<\1i>!g
    s!<\(/\)\?\(b\|strong\)\(\s[^>]*\)\?>!<\1b>!g
    s!<\(/\)\?\(del\|s\)\(\s[^>]*\)\?>!<\1s>!g
    s!<\(/\)\?\(code\|tt\|kbd\)\(\s[^>]*\)\?>!<\1code>!g
    s!<\(/\)\?\(pre\)\(\s[^>]*\)\?>!\n<\1pre>\n!g

    # Inline codes
    s!\(&acute;\|`\)!´!gI
    s!<code>\([^<]*\)\?<\(a\|b\|i\|em\|s\|code\)>\([^<]*\)\?</\2>\([^<]*\)\?</code>!<code>\1\3\4</code>!g
    s!["'"'"'"(]*<code\(\s\+[^>]*\)\?>!`!g
    s!</code>["'"'"'")]*!`!g

    # White lines before block starts
    s!<\(/\)\?\(p\|pre\|div\|blockquote\|[dou]l\|section\|article\|nav\|header\|footer\)\(\s[^>]*\)\?>!\n\n<\1\2\3>\n!g

    # Headers
    s!<h1>\s*!# !g
    s!<h2>\s*!## !g
    s!<h3>\s*!### !g
    s!<h4>\s*!#### !g
    s!<h5>\s*!##### !g
    s!<h6>\s*!###### !g
    s!</h[1-6]>!!g

    # Anchor link
    s!<a\s\+name="\([^"]\+\)"[^>]*>\([^<]*\)</a>\(.*\)$!\2 \3 <a name="\1"></a>!g;

    # Anchor references

    s/<a\s\+href="\([^"]\+\)\?">\([^<]\+\)<\/a>/[\2](\1)/gI

    # Most of Entitities, except &lt; &gt; and &amp
    s!&copy;!©!gI
    s!&\(ndash\|emdash\|dash\);!—!gI
    s!&nbsp;! !gI
    s!&sect;!§!gI

  '< "$infile" | sed '
    # Preformated code
    s!\t\t\t\t\t!                    !g
    s!\t\t\t\t!                !g
    s!\t\t\t!            !g
    s!\t\t!        !g
    s!\t!    !g

    s!<pre>\(.*\)</pre>!<pre>\n\1\n</pre>!g
    /<pre>/,/<\/pre>/{
      s!</\?[^>]*>!!g
      /^$/!s!^\(\s\{0,2\}\)\?\([^ ]\)!    \1\2!
    }

    /<span class="apii">/s!\(<\/\?em>\)!!g
    /<a name/s!^\s*!!g
    s!^\s*<span class="apii">\([^<]*\)<\/span>!* \1!g

    /<hr>/{
      s!<hr>#!<hr>\n#!
      s!<hr>!------------------------------------------------------------\n!
    }

    /<!--/,/-->/d


    # Formatting
    s!<b\(\s[^>]*\)\?>\s*!**!g;  s!\s*<\/b\(\s[^>]*\)\?>!**!g
    s!<i\(\s[^>]*\)\?>\s*!_!g;   s!\s*<\/i\(\s[^>]*\)\?>!_!g
    s!<em\(\s[^>]*\)\?>\s*!!g;   s!\s*<\/em\(\s[^>]*\)\?>!!g

    # Lists
    s!^\s*<li\(\s[^>]*\)\?>!* !g

    # Clean tags and other stuff
    s!<\/\?\(li\|[dou]l\|p\|small\)\(\s[^>]*\)\?>!!g
    s!^\s\+$!!g

    s!´!`!g


    s!\*\*"\([^"]\+\)"\([^*]\+\)\?\*\*!`\1`\2!g
    s!\*\*`\([^`]\+\)`\([^*]\+\)\?\*\*!`\1`\2!g
    s!\*\*'"'"'\([^'"'"']\+\)'"'"'\([^*]\+\)\?\*\*!`\1`\2!g

 ;
 ' | uniq | sed '
   # Linearize all
    :A; N
    s/\n/ˇ/g
    $!TB;bA;:B
 ' | sed '
    # Operations multi line
    s!`\s*ˇˇ<a name!` <a name!g
    s!ˇ\*\s*ˇ!ˇ* !g

    s!\([^ˇ]\)ˇ\([^ˇ ]\)!\1 \2!g

    # Document attribution (at Top)
    s!#\s\+<a href="\([^"]\+\)"[^<]\+<img[^<]\+</a>\s*\([^ˇ]\+\)!# \2\n\n[Lua Language](\1)!I

    # Delinearize
    s!ˇ!\n!g
  ' | sed '
    /^\[contents\]/r '"$index"'
    #/^\[contents\]/r /dev/null
    /^\[contents\]/d

    s/^#/\n----------------------------------------\n\n\n#/g
    /^-----\+$/d
    /^\[index\]/,/^\[other versions\]/d;
    s!&middot;!·!g
    # Finally, the reserved entities
    s!&lt;!<!gI
    s!&gt;!>!gI
    s!&amp;!&!gI
    s!&[lr]squo;!`!g
    s!\s"\(\*[^"]\+\)"! `\1`!g
  ' > "$outfile"
}

process_index() {
  local index="$1"
  local outfile="$2"
  sed '
    # Manual 5.1+
    1,/<\/SMALL>/d

    # Manual 5.4

    /<SMALL/,$d
     s!<H[^>]\+>&nbsp;</H[^>]\+>!!
    s!<\/\?\(td\|tr\|table\|p\|ol\|ul\|li\|br\|hr\|div\)\([^>]\+\)\?>!!gI
    s!<H1\(\s[^>]\+\)\?>!# !
    s!<H2\(\s[^>]\+\)\?>!## !
    s!<H3\(\s[^>]\+\)\?>!### !
    s!<H4\(\s[^>]\+\)\?>!#### !
    s!<H5\(\s[^>]\+\)\?>!##### !
    s!<H6\(\s[^>]\+\)\?>!###### !
    s!</H[1-6]>!\n!
    s!^<A !* <A !
    s!&\(ndash\|emdash\|dash\);!—!gI


    # Anchor references
    s!manual.html\(#\)\?!#!
    s!<a\s*href="\([^"]\+\)">_\([^>]*\)</a>![`_\2`](\1)!gI
    /#pdf\|#lua_\|luaL_/!{
      s!<a\s*href="\([^"]\+\)">\([^>]*\)</a>![\2](\1)!gI
    }
    /#pdf\|#lua_\|luaL_/{
      s!<a\s*href="\([^"]\+\)">\([^>]*\)</a>![`\2`](\1)!gI
    }

    # Anchor Links
    s!<a\s*name="\([^"]\+\)"[^>]*>\([^<]*\)</a>\(.*\).$!\2 \3 <a name="\1"></a>!gI

    /<!--/,/-->/d
    /<\/[bB][oO][dD][yY]/,$d


  ' < "$1" |uniq > "$outfile"
}


list_src_docs() {
  for file in $(find . -name 'manual.html' | grep doc); do
    local version="$(echo "$file" | cut -d/ -f3 | cut -d. -f1-2)"
    #if [[ "$version" != "lua-5.2" ]]; then continue; fi
    local index="$(dirname "$file")"/contents.html
    local outfile="${version}-manual.md"
    process_index "$index" _tmpindex.md
    #if [[ "$version" == "lua-5.2" ]] ; then break; fi

    process_manual "$file" _tmpindex.md "$outfile"
    rm -f _tmpindex*

  done
}


download_src
list_src_docs

