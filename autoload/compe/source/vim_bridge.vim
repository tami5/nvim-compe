let s:source_id = 0
let s:sources = {}

"
" compe#source#vim_bridge#register
"
function! compe#source#vim_bridge#register(id, source) abort
  let s:source_id += 1
  let l:id = a:id . '_' . s:source_id
  let s:sources[l:id] = a:source
  call luaeval('require"compe":register_vim_source(_A[1])', [l:id])
  return l:id
endfunction

"
" compe#source#vim_bridge#unregister
"
function! compe#source#vim_bridge#unregister(id) abort
  if has_key(s:sources, a:id)
    unlet s:sources[a:id]
    call luaeval('require"compe":unregister_source(_A[1])', [a:id])
  endif
endfunction

"
" compe#source#vim_bridge#get_source_metadata
"
function! compe#source#vim_bridge#get_source_metadata(id) abort
  if has_key(s:sources, a:id) && has_key(s:sources[a:id], 'get_source_metadata')
    return s:sources[a:id].get_source_metadata()
  endif
  return {}
endfunction

"
" compe#source#vim_bridge#get_item_metadata
"
function! compe#source#vim_bridge#get_item_metadata(id, item) abort
  if has_key(s:sources, a:id) && has_key(s:sources[a:id], 'get_item_metadata')
    return s:sources[a:id].get_item_metadata(a:item)
  endif
  return {}
endfunction

"
" compe#source#vim_bridge#datermine
"
function! compe#source#vim_bridge#datermine(id, context) abort
  if has_key(s:sources, a:id) && has_key(s:sources[a:id], 'datermine')
    return s:sources[a:id].datermine(a:context)
  endif
  return {}
endfunction

"
" compe#source#vim_bridge#complete
"
function! compe#source#vim_bridge#complete(id, args) abort
  if has_key(s:sources, a:id) && has_key(s:sources[a:id], 'complete')
    let a:args.callback = { result ->
    \   luaeval('require"compe.completion.source.vim_bridge".on_callback(_A[1], _A[2])', [a:id, result])
    \ }
    let a:args.abort = { ->
    \   luaeval('require"compe.completion.source.vim_bridge".on_abort(_A[1])', [a:id])
    \ }
    call s:sources[a:id].complete(a:args)
  endif
endfunction
