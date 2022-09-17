# for store buf list
declare-option -hidden str buffer_manager_buflist
# for store latest buf
declare-option -hidden str buffer_manager_latest_bufname
# for store toggle help info
declare-option -hidden bool buffer_manager_is_show_help_info true
remove-hooks global buffer-manager
hook -group buffer-manager global WinDisplay .* %{
    eval  %sh{
        if [ "$kak_bufname" = "*buffer-manager*" ]; then
            printf "buffer-manager-render-buflist\n"
        else
            printf 'set-option global buffer_manager_latest_bufname "%s"\n' "$kak_bufname"
        fi

    }
}
define-command -hidden -override buffer-manager-render-buflist %{
    # init store
   set-option global buffer_manager_buflist ""
   evaluate-commands -no-hooks -buffer * %{
        eval %sh{
            if [ "$kak_bufname" != "*debug*" ] &&  [ "$kak_bufname" != "*buffer-manager*" ] ; then
                bufline_prefix=""
                if [ "$kak_opt_buffer_manager_latest_bufname" = "$kak_bufname" ]; then
                    bufline_prefix=">"
                else
                    bufline_prefix=" "
                fi

                if [ "$kak_modified" = true ]; then
                    bufline_prefix+="+"
                else
                    bufline_prefix+=" "
                fi
                printf 'set-option global buffer_manager_buflist "%s%s %s\n"\n' "$kak_opt_buffer_manager_buflist" "$bufline_prefix" "$kak_bufname"
            fi
        }
    }

    eval %sh{
        if [ ! -z "$kak_opt_buffer_manager_buflist" ]; then
            printf "%s\n" "exec '%|printf<space>\"\$kak_opt_buffer_manager_buflist\"<ret>'"
        fi
    }
    # select by line
    exec '%<a-s>'
    try %{
        # remove empty line, if any
        exec -draft "<a-k>^$<ret>d"
    }
    try %{
        # select current one
        exec "<a-k>^[> ][+ ] %opt{buffer_manager_latest_bufname}$<ret>gl"
    } catch %{
        exec gggl
    }

    map -docstring "open buffer" buffer normal <ret> ': buffer-manager-open<ret>'
    map -docstring "delete current line or selected buffer" buffer normal <d> ': buffer-manager-delete<ret>'
    map -docstring "force delete current line or selected buffer" buffer normal <D> ': buffer-manager-delete-force<ret>'
    map -docstring "delete current line or selected buffer and back" buffer normal <a-d> ': buffer-manager-delete<ret>ga'
    map -docstring "force delete current line or selected buffer and back" buffer normal <a-D> ': buffer-manager-delete-force<ret>ga'
    map -docstring "back to last" buffer normal <esc> 'ga'
    map -docstring "delete all buffers" buffer normal <q> ': evaluate-commands -buffer * %{ delete-buffer }<ret>'
    map -docstring "force delete all buffers" buffer normal <Q> ': evaluate-commands -buffer * %{ delete-buffer! }<ret>'
    map -docstring "delete other buffers except current line or selected lines" buffer normal <e> ': buffer-manager-delete-others<ret>'
    map -docstring "force delete other buffers except current line or selected lines" buffer normal <E> ': buffer-manager-delete-others-force<ret>'
    map -docstring "toggle help info" buffer normal <?> ': buffer-manager-help<ret>'
    buffer-manager-help
}

define-command -override buffer-manager %{
    edit -scratch *buffer-manager*
}

define-command -hidden -override buffer-manager-toggle-help %{
    eval %sh{
        if [ "$kak_opt_buffer_manager_is_show_help_info" = true ];then
         printf 'set-option global buffer_manager_is_show_help_info false\n'
        else
         printf 'set-option global buffer_manager_is_show_help_info true\n'
        fi
    }
    buffer-manager-help
}
define-command -hidden -override buffer-manager-help %{
    eval %sh{
        if [ "$kak_opt_buffer_manager_is_show_help_info" = true ];then
            USAGE='<ret>: open buffer
d: delete current line or selected buffers
D: force delete current line or selected buffers
<esc>: back to last buffer
q: delete all buffers
Q: force delete all buffers
e: delete other buffers except selected buffers
E: force deleted other buffers except seleted buffers
<a-d>: delete selected buffers and back
<a-D>: force deleted seleted buffers and back
<?>: toggle show help info
';
            printf "info -title 'Buffer Manager Help' '%s'\n" "$USAGE";
        else
          printf "exec <esc>\n"
        fi
    }
}

define-command -hidden -override buffer-manager-open %{
    buffer-manager-select
    eval %sh{
      current_selection="$kak_selection"
      # first dismiss selection
      printf 'exec gl\n'
      printf 'buffer "%s"\n' "$current_selection"
    }
}

define-command -override -hidden  buffer-manager-select %{
    eval %sh{
        lines=();
        for val in "$kak_selections_desc";
            do
                left_field=$(echo $val | cut -f1 -d,)
                right_field=$(echo $val | cut -f2 -d,)

                left_line=$(echo $left_field | cut -f1 -d.)
                right_line=$(echo $right_field | cut -f1 -d.)

                # sort left, right
                if [ $left_line -gt $right_line ]; then
                    start_line=$right_line;
                    end_line=$left_line;
                else
                    start_line=$left_line;
                    end_line=$right_line;
                fi
                for line in $(seq $start_line $end_line)
                    do
                        lines+=($line)
                    done
        done
        printf "select "
        for line in "${lines[@]}"; do
            printf "%s.4,%s.9999 " $line $line
        done
        printf "\n"
        printf "exec H\n"
    }
}
define-command -override -hidden  buffer-manager-select-others %{
    eval %sh{
        lines=()
        for val in "$kak_selections_desc";
            do
                left_field=$(echo $val | cut -f1 -d,)
                right_field=$(echo $val | cut -f2 -d,)

                left_line=$(echo $left_field | cut -f1 -d.)
                right_line=$(echo $right_field | cut -f1 -d.)

                # sort left, right
                if [ $left_line -gt $right_line ]; then
                    start_line=$right_line;
                    end_line=$left_line;
                else
                    start_line=$left_line;
                    end_line=$right_line;
                fi
                for line in $(seq $start_line $end_line)
                    do
                        lines+=($line)
                    done
        done
        selected_lines=""

        for line in $(seq 1 $kak_buf_line_count); do
            if [[ ! " ${lines[*]} " =~ " ${line} " ]]; then
                selected_lines+="$line.4,$line.9999 "
            fi
        done
        if [ -z "$selected_lines"]; then
            printf 'fail "There are no buffers left"\n'
        else
            printf "select %s\n" $selected_lines
            printf "exec H\n"
        fi
    }
}
define-command -hidden -override buffer-manager-delete %{
    buffer-manager-select
    eval -itersel %{
       try %{
           delete-buffer "%val{selection}"
           exec "xd"
       } catch %{
           fail %val{error}
       }
    }
    buffer-manager-close-list-when-empty
}
define-command -hidden -override buffer-manager-delete-force %{
    buffer-manager-select
    eval -itersel %{
       try %{
           delete-buffer! "%val{selection}"
           exec "xd"
       } catch %{
           fail %val{error}
       }
    }
    buffer-manager-close-list-when-empty
}
define-command -hidden -override buffer-manager-delete-others %{
    buffer-manager-select-others
    eval -itersel %{
       try %{
           delete-buffer "%val{selection}"
           exec "xd"
       } catch %{
           fail %val{error}
       }
    }
    buffer-manager-close-list-when-empty
}
define-command -override -hidden buffer-manager-delete-others-force %{
    buffer-manager-select-others
    eval -itersel %{
       try %{
           delete-buffer! "%val{selection}"
           exec "xd"
       } catch %{
           fail %val{error}
       }
    }
    buffer-manager-close-list-when-empty
}
define-command -hidden -override buffer-manager-close-list-when-empty %{

    try %{
        exec -draft '/..<ret>'
    } catch %{
        try %{ delete-buffer *buffer-manager* }
    }
}
