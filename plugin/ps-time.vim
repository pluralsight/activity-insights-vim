function! s:UnixTimeMs()
  return float2nr(reltimefloat(reltime()) * 1000)
endfunction

let g:last_event_time = s:UnixTimeMs()
let g:cache_bust_delay = 60000
let g:timer_delay = g:cache_bust_delay - 10
let g:is_windows = has('win32') || has('win64')
let g:home = fnamemodify('~', ':p')
let g:isRegistered = 0
let g:creds_path = ''
let g:binary_path = ''
let g:last_file = ''
let g:ignore_files = ['MERGE_MSG', 'COMMIT_EDITMSG']
let g:pulses = []

function! s:SetPaths()
  if g:creds_path == ''
    if g:is_windows
      let g:creds_path = printf('%sw', g:home . '\.pluralsight' . '\credentials.yaml')
    else
      let g:creds_path = g:home . '.pluralsight/credentials.yaml'
    endif
  endif

  if g:binary_path == ''
    let g:binary_path = expand('<sfile>:p:h:h') . '/ps-time'

    if g:is_windows
      let g:binary_path = g:binary_path . '.exe'
    endif
  endif
endfunction

function! s:IsRegistered()
  if filereadable(g:creds_path)
    let lines = readfile(g:creds_path)
    for line in lines
      let match = split(line, ': ')

      if match[0] == 'api_token'
        return 1
      endif
    endfor
  endif

  return 0
endfunction

function! PSTIME_ProcessPulses(a)
  call s:SendPulses()
endfunction

function! s:StartPsTime()
  augroup PsTime
    autocmd CursorMoved,CursorMovedI * call s:TypingActivity()
    autocmd BufWritePost * call s:SavingActivity()
  augroup END

  let timer = timer_start(g:timer_delay, 'PSTIME_ProcessPulses', {'repeat': -1})
endfunction

function! s:Init()
  call s:SetPaths()
  if s:IsRegistered()
    call s:StartPsTime()
  endif
endfunction

function! s:SendPulses()
  if len(g:pulses)
    let encoded_pulses = json_encode(g:pulses)
    let g:pulses = []

    let job = job_start([g:binary_path])
    let channel = job_getchannel(job)
    call ch_sendraw(channel, encoded_pulses)
    call ch_close_in(channel)
  endif
endfunction

function! s:ShouldIgnore(file_name)
  return index(g:ignore_files, a:file_name) >= 0
endfunction

function! s:CreatePulse(event_date, event_type)
  return { 'filePath': g:last_file, 'eventType': a:event_type, 'eventDate': a:event_date, 'editor': 'Vim'}
endfunction

function! s:TypingActivity()
  let current_file = expand('%:p')

  if s:ShouldIgnore(current_file)
    return
  endif

  let now = s:UnixTimeMs()

  if (current_file != g:last_file) || ((now - g:last_event_time) > g:cache_bust_delay)
    let g:last_event_time = now
    let g:last_file = current_file
    let pulse = s:CreatePulse(now, 'saveFile')

    call add(g:pulses, pulse)
  endif
endfunction

function! s:SavingActivity()
  let current_file = expand('%:p')

  if s:ShouldIgnore(current_file)
    return
  endif

  let now = s:UnixTimeMs()
  let g:last_event_time = now
  let g:last_file = expand('%:p')
  let pulse = s:CreatePulse(now, 'saveFile')

  call add(g:pulses, pulse)
endfunction

function! PSTIME_RegisterComplete(status, exit_code)
  " Because this is an exit code, a falsy value means success
  if a:exit_code
    echo "There was a problem attempting to register, if the problem persists please contact support"
  else
    call s:StartPsTime()
  endif
endfunction

function! s:Register()
  if s:IsRegistered()
    echo 'Already successfully registered'
    return
  endif

  let job = job_start([g:binary_path, 'register'], {'exit_cb': 'PSTIME_RegisterComplete'})
endfunction

call s:Init()

:command -nargs=0 PsTimeRegister call s:Register()
