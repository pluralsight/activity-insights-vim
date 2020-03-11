let g:is_neovim = has('nvim')

function! s:UnixTimeMs()
  if g:is_neovim
    return localtime() * 1000
  else
    return float2nr(reltimefloat(reltime()) * 1000)
  endif
endfunction

let g:last_event_time = s:UnixTimeMs()
let g:cache_bust_delay = 60000
let g:timer_delay = g:cache_bust_delay - 10
let g:is_windows = has('win32') || has('win64')
let g:is_neovim = has('nvim')
let g:home = fnamemodify('~', ':p')
let g:isRegistered = 0
let g:creds_path = ''
let g:binary_path = ''
let g:last_file = ''
let g:editor = ''
let g:ignore_files = ['MERGE_MSG', 'COMMIT_EDITMSG']
let g:pulses = []

if g:is_neovim
  let g:editor = 'Neovim'
else
  let g:editor = 'Vim'
endif

function! s:SetPaths()
  if g:creds_path == ''
    if g:is_windows
      let g:creds_path = printf('%sw', g:home . '\.pluralsight' . '\credentials.yaml')
    else
      let g:creds_path = g:home . '.pluralsight/credentials.yaml'
    endif
  endif

  if g:binary_path == ''
    let g:binary_path = g:home . '.pluralsight/ps-time'

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

    if g:is_neovim
      let job = jobstart([g:binary_path])
      call jobsend(job, encoded_pulses)
      call jobclose(job, 'stdin')
    else
      let job = job_start([g:binary_path])
      let channel = job_getchannel(job)
      call ch_sendraw(channel, encoded_pulses)
      call ch_close_in(channel)
    endif
  endif
endfunction

function! s:ShouldIgnore(file_name)
  return index(g:ignore_files, a:file_name) >= 0
endfunction

function! s:CreatePulse(event_date, event_type)
  return { 'filePath': g:last_file, 'eventType': a:event_type, 'eventDate': a:event_date, 'editor': g:editor}
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
    let pulse = s:CreatePulse(now, 'typing')

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
  " Because this is an exit code, 0 means success
  if a:exit_code == 0
    call s:StartPsTime()
  else
    echo "There was a problem attempting to register, if the problem persists please contact support"
  endif
endfunction

function! PSTIME_NVIM_RegisterComplete(job_id, exit_code, event)
  call PSTIME_RegisterComplete(a:event, a:exit_code)
endfunction

function! s:Register()
  if s:IsRegistered()
    echo 'Already successfully registered'
    return
  endif

  if g:is_neovim
    let job = jobstart([g:binary_path, 'register'], {'on_exit': 'PSTIME_NVIM_RegisterComplete'})
  else
    let job = job_start([g:binary_path, 'register'], {'exit_cb': 'PSTIME_RegisterComplete'})
  endif
endfunction

call s:Init()

:command! -nargs=0 PsTimeRegister call s:Register()
