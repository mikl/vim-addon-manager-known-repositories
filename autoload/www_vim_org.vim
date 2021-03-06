" get list of all availible packages on www.vim.org
" The result can be pasted into
" plugin/vim-addon-manager-known-repositories.vim

" throws fine if end of scripts has been reached
fun! www_vim_org#Script(nr, cached)
  let nr = a:nr
  let page_url = 'http://www.vim.org/scripts/script.php?script_id='.nr
  let error = {'title2': 'error', 'vim_script_nr': nr}

  if !exists('g:www_vim_org_cache')
    let g:www_vim_org_cache = {}
  endif

  if a:cached && has_key(g:www_vim_org_cache, page_url)
    let str = g:www_vim_org_cache[page_url]
    let shell_error1 = 0
  else
    let str = system('curl '.shellescape(page_url,":?='").' 2>/dev/null')
    let shell_error1 = v:shell_error
  endif

  if str =~ 'Vim Online Error' || shell_error1 != 0
   if (nr -1) > 2900 || shell_error1 != 0
    echo "end reached? script nr ".(nr -1)
      throw "fine"
    else
      return error
    endif
  endif

  let lines = split(str,"\n")

  let g:www_vim_org_cache[page_url] = str

  let title = matchstr(lines[5], '<title>\zs.*\ze -')


  let match_author = '<tr><td><a href="/account/profile.php?user_id=\d*">\([^<]\+\)</a></td></tr>'
  let backup = lines
  while len(lines) > 0 && lines[0] !~ match_author
    let lines = lines[1:]
  endwhile
  if (len(lines) > 0)
    let author = matchlist(lines[0], match_author)[1]
  else
    let author=""
    let lines = backup
  endif

  while len(lines) > 0 && lines[0] !~ 'class="prompt">script type</td>'
    let lines = lines[1:]
  endwhile
  if (empty(lines))
    return error
  endif

  let type = matchstr(lines[1], 'td>\zs[^<]*\ze')

  while len(lines) > 0 && lines[0] !~ 'download_script.php'
    let lines = lines[1:]
  endwhile

  if (empty(lines))
    return error
  endif
  let url = 'http://www.vim.org/scripts/download_script.php?src_id='.matchstr(lines[0], '.*src_id=\zs\d\+\ze')
  let archive_name = matchstr(lines[0], '">\zs[^<]*\ze')
  let v = matchstr(lines[1], '<b>\zs[^<]*\ze')
  let date = matchstr(lines[2], '<i>\zs[^<]*\ze')
  let vim_version = matchstr(lines[3], 'nowrap>\zs[^<]*\ze')

  " keep names simple. Eg ',' can be quoted in runtimepath. Yet I think KISS
  " is better for all. Also keeping '.' so that less names break
  " old line was :let title2=substitute(title,"[+:'()\\/]",'','g')
  " If UTF-8 chars are used in the futures this has to change.
  let title2=substitute(title,'[^ a-zA-Z0-9_\-.]','','g')
  let title2=substitute(title2," ",'_','g')
  " also remove trailing .vim
  let title2=substitute(title2,'\.vim$','','g')

  return {
    \ 'type' : 'archive',
    \ 'archive_name' : archive_name,
    \ 'url' : url,
    \ 'version' : v,
    \ 'date' : date,
    \ 'vim_script_nr' : nr,
    \ 'script-type' : type,
    \ 'vim_version' : vim_version,
    \ 'title'  : title,
    \ 'title2' : title2,
    \ 'author' : author
    \ } 
endf

" usage: insert mode: <c-r>=www_vim_org#List()
fun! www_vim_org#List()
  " first collect in a dict because some names are used more than once

  let nr=1
  let d = {}

  while 1
    let nr = nr +1
    "echo nr

    try
      let dict = www_vim_org#Script(nr, 1)
    catch /fine/
      break
    endtry

    let d[dict['title2']] = get(d, dict['title2'], [])
    call add(d[dict['title2']], dict)
    unlet dict['title2']
  endwhile

  " now create final list.
  " if there are >1 items append script id to the key

  let list = []
  for [k,v] in items(d)
    if len(v) > 1
      for v2 in v
        call add(list, "let s:plugin_sources['". k . v2['vim_script_nr']."'] = ".string(v2))
      endfor
    else
      call add(list, "let s:plugin_sources['".k."'] = ".string(v[0]))
    endif
  endfor

  return list

endf

let s:plugin_dir=fnamemodify(expand('<sfile>'), ':h:h')

fun! www_vim_org#Update()
  let f = s:plugin_dir.'/plugin/vim-addon-manager-known-repositories.vim'
  let lines = readfile(f)
  let new_file = []
  let nr = 0
  while nr < len(lines)
    if lines[nr] =~ '" automatically generated by www_vim_org#List() {{{'
      call add(new_file, lines[nr])
      let nr = nr +1

      " skip old information
      while nr < len(lines) && lines[nr] !~ '" }}}'
        let nr = nr +1
      endwhile

      " add new information
      call extend(new_file, www_vim_org#List())
    else
      call add(new_file, lines[nr])
      let nr = nr +1
    endif
  endwhile
  call writefile(new_file, f)
endf
