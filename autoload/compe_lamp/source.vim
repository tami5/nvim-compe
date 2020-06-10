let s:Position = vital#lamp#import('VS.LSP.Position')

let s:state = {
\   'ids': [],
\   'cancellation_token': lamp#cancellation_token(),
\ }

"
" compe_lamp#source#register
"
function! compe_lamp#source#register() abort
  augroup compete#source#lamp#register
    autocmd!
    autocmd User lamp#server#initialized call s:source()
    autocmd User lamp#server#exited call s:source()
  augroup END
  call s:source()
endfunction

"
" source
"
function! s:source() abort
  for l:id in s:state.ids
    call compe#source#vim_bridge#unregister(l:id)
  endfor
  let s:state.ids = []

  let l:servers = lamp#server#registry#all()
  let l:servers = filter(l:servers, { _, server -> server.supports('capabilities.completionProvider') })
  let s:state.ids = map(copy(l:servers), { _, server ->
  \   compe#source#vim_bridge#register(server.name, {
  \     'get_source_metadata': function('s:get_source_metadata'),
  \     'get_item_metadata': function('s:get_item_metadata'),
  \     'datermine': function('s:datermine', [server]),
  \     'complete': function('s:complete', [server]),
  \   })
  \ })
endfunction

"
" s:get_source_metadata
"
function! s:get_source_metadata() abort
  return {
  \   'priority': 1000,
  \ }
endfunction

"
" s:get_item_metadata
"
function! s:get_item_metadata(item) abort
  return {
  \   'menu': '[l]'
  \ }
endfunction

"
" s:datermine
"
function! s:datermine(server, context) abort
  if index(a:server.filetypes, a:context.filetype) == -1
    return {}
  endif

  let [l:_, l:keyword_pattern_offset, l:__] = matchstrpos(a:context.before_line, '\w\+$')
  let l:keyword_pattern_offset += 1

  let l:trigger_chars = a:server.capability.get_completion_trigger_characters()
  if index(l:trigger_chars, a:context.before_char) >= 0
    return {
    \   'keyword_pattern_offset': l:keyword_pattern_offset,
    \   'trigger_character_offset': a:context.col,
    \ }
  endif

  if l:keyword_pattern_offset > 0
    return {
    \   'keyword_pattern_offset': l:keyword_pattern_offset,
    \ }
  endif

  return {}
endfunction

"
" complete
"
function! s:complete(server, args) abort
  if index(a:server.filetypes, a:args.context.filetype) == -1
    return a:args.abort()
  endif

  call s:state.cancellation_token.cancel()
  let s:state.cancellation_token = lamp#cancellation_token()

  let l:context = {
  \   'triggerKind': a:args.trigger_character_offset > 0 ? 2 : (a:args.incomplete ? 3 : 1),
  \ }

  if a:args.trigger_character_offset > 0
    let l:context.triggerCharacter = a:args.context.before_char
  endif

  let l:compete_position = s:Position.cursor()
  let l:promise = a:server.request('textDocument/completion', {
  \   'textDocument': lamp#protocol#document#identifier(bufnr('%')),
  \   'position': l:compete_position,
  \   'context': l:context,
  \ }, {
  \   'cancellation_token': s:state.cancellation_token,
  \ })
  let l:promise = l:promise.catch({ -> a:args.abort() })
  let l:promise = l:promise.then({ response ->
  \   s:on_response(
  \     a:server,
  \     a:args,
  \     l:compete_position,
  \     response
  \   )
  \ })
endfunction

"
" on_response
"
function! s:on_response(server, args, complete_position, response) abort
  if index([type([]), type({})], type(a:response)) == -1
    return a:args.abort()
  endif

  call a:args.callback({
  \   'items': lamp#feature#completion#convert(
  \     a:server.name,
  \     a:complete_position,
  \     a:response,
  \   ),
  \   'incomplete': type(a:response) == type({}) ? get(a:response, 'isIncomplete', v:false) : v:false,
  \ })
endfunction

