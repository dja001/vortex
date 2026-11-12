" vortex.vim: vim side of vortex, sourced by `vortex start` (vim 8.2+).
"
" A timer polls .vortex/state/vim_request.json, written by `vortex submit`:
"   lock    write all buffers, make them read-only, report the cursor
"   unlock  make them writable again
"   reload  unlock, reload the files Claude changed, restore the view
" A lock is only taken in normal mode, so typing is never interrupted.

if exists('g:vortex_loaded') || !exists('g:vortex_dir')
  finish
endif
let g:vortex_loaded = 1

let s:docdir = fnamemodify(g:vortex_dir, ':h')
let s:state = g:vortex_dir . '/state'
let s:req = s:state . '/vim_request.json'
let s:resp = s:state . '/vim_response.json'
let s:pidfile = s:state . '/vim.pid'
let s:locked = []
let s:lock_time = 0

call mkdir(s:state, 'p')
call writefile([getpid()], s:pidfile)

function! s:DocBuffers() abort
  return filter(getbufinfo({'buflisted': 1}),
        \ {_, b -> b.name !=# '' && stridx(resolve(b.name), s:docdir . '/') == 0})
endfunction

function! s:SaveAll() abort
  silent! wall
  let unsaved = map(filter(s:DocBuffers(), {_, b -> b.changed}),
        \ {_, b -> fnamemodify(b.name, ':t')})
  if !empty(unsaved)
    throw 'could not write ' . join(unsaved, ', ')
  endif
endfunction

function! s:Lock() abort
  call s:SaveAll()
  let s:locked = []
  for b in getbufinfo({'buflisted': 1})
    if b.name !=# '' && getbufvar(b.bufnr, '&modifiable')
      call setbufvar(b.bufnr, '&modifiable', 0)
      call add(s:locked, b.bufnr)
    endif
  endfor
  let s:lock_time = localtime()
  let v = winsaveview()
  return {'file': resolve(expand('%:p')), 'lnum': v.lnum, 'topline': v.topline}
endfunction

function! s:Unlock() abort
  for b in s:locked
    if bufexists(b)
      call setbufvar(b, '&modifiable', 1)
    endif
  endfor
  let s:locked = []
endfunction

function! s:Reload(req) abort
  call s:Unlock()
  let changed = get(a:req, 'changed', [])
  let save_ar = &autoread
  set autoread
  try
    if index(changed, resolve(expand('%:p'))) >= 0
      let v = winsaveview()
      if has_key(a:req, 'lnum')
        let v.lnum = a:req.lnum
        let v.topline = a:req.topline
      endif
      " :edit! keeps the undo history (see 'undoreload'): u undoes the merge
      silent edit!
      call winrestview(v)
    endif
    silent! checktime
  finally
    let &autoread = save_ar
  endtry
  redraw
  echom 'vortex: Claude''s changes are in (u to undo)'
endfunction

function! s:Poll(timer) abort
  if !empty(s:locked) && localtime() - s:lock_time > 60
    call s:Unlock()
    echohl WarningMsg | echom 'vortex: lock timed out, buffers unlocked' | echohl None
  endif
  if !filereadable(s:req)
    return
  endif
  try
    let req = json_decode(join(readfile(s:req), ''))
  catch
    return
  endtry
  let m = mode()
  if (req.op ==# 'lock' && m !=# 'n') || m ==# 'c' || getcmdwintype() !=# ''
    return
  endif
  call delete(s:req)
  let resp = {'id': req.id, 'ok': v:true}
  try
    if req.op ==# 'lock'
      call extend(resp, s:Lock())
    elseif req.op ==# 'unlock'
      call s:Unlock()
    elseif req.op ==# 'reload'
      call s:Reload(req)
    else
      throw 'unknown request ' . req.op
    endif
  catch
    call s:Unlock()
    let resp.ok = v:false
    let resp.error = v:exception
  endtry
  call writefile([json_encode(resp)], s:resp . '.tmp')
  call rename(s:resp . '.tmp', s:resp)
endfunction

function! s:Run(args) abort
  let out = system(shellescape(g:vortex_bin) . ' ' . a:args
        \ . ' --project ' . shellescape(s:docdir) . ' 2>&1')
  redraw
  echo substitute(out, '\n\+$', '', '')
endfunction

function! s:Batch() abort
  try
    call s:SaveAll()
  catch
    echohl ErrorMsg | echom 'vortex: ' . v:exception | echohl None
    return
  endtry
  call s:Run('batch')
endfunction

command! VortexBatch call <SID>Batch()
command! VortexStatus call <SID>Run('status')
command! VortexAbort call <SID>Run('abort')
command! VortexLog call <SID>Run('log -n 15')

if empty(maparg('<Leader>vb', 'n'))
  nnoremap <silent> <Leader>vb :VortexBatch<CR>
endif
if empty(maparg('<Leader>vs', 'n'))
  nnoremap <silent> <Leader>vs :VortexStatus<CR>
endif

let s:timer = timer_start(200, function('s:Poll'), {'repeat': -1})

augroup vortex
  autocmd!
  autocmd VimLeave * call delete(s:pidfile)
augroup END
