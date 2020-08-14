let g:is_neovim = has('nvim')
let g:TOS_NOT_ACCEPTED_STATUS = 100

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
let g:is_unix = has('unix')
let g:is_osx = has('macunix')
let g:is_supported_os = g:is_windows || g:is_unix || g:is_osx
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
    let g:binary_path = g:home . '.pluralsight/activity-insights'

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

      if match[0] == 'api_token' && match[1] != '~'
        return 1
      endif
    endfor
  endif

  return 0
endfunction

function! PLURALSIGHT_ProcessPulses(a)
  call s:SendPulses()
endfunction

function! s:StartPluralsight()
  augroup Pluralsight
    autocmd CursorMoved,CursorMovedI * call s:TypingActivity()
    autocmd BufWritePost * call s:SavingActivity()
  augroup END

  let timer = timer_start(g:timer_delay, 'PLURALSIGHT_ProcessPulses', {'repeat': -1})
endfunction

function! s:Init()
  if g:is_supported_os
    call s:SetPaths()

    if s:IsRegistered()
      call s:StartPluralsight()
    endif
  else
    echo 'This OS is not supported by Pluralsight Activity Insights'
  endif
endfunction

function! s:SendPulses()
  if len(g:pulses)
    let encoded_pulses = json_encode(g:pulses)
    let g:pulses = []

    if g:is_neovim
      let job = jobstart([g:binary_path], {'out_io': 'buffer', 'out_name': 'tosText', 'exit_cb': 'PLURALSIGHT_NVIM_DashboardCallback'})
      call jobsend(job, encoded_pulses)
      call jobclose(job, 'stdin')
    else
      let job = job_start([g:binary_path], {'out_io': 'buffer', 'out_name': 'tosText', 'exit_cb': 'PLURALSIGHT_DashboardCallback'})
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

function! PLURALSIGHT_RegisterComplete(job, exit_code)
  " Because this is an exit code, 0 means success
  if a:exit_code == 0
    call s:StartPluralsight()
  elseif a:exit_code == g:TOS_NOT_ACCEPTED_STATUS
    call s:ShowTOS()
  else
    echo "There was a problem attempting to register, if the problem persists please contact support"
  endif
endfunction

function! PLURALSIGHT_NVIM_RegisterComplete(job_id, exit_code, event)
  call PLURALSIGHT_RegisterComplete(a:event, a:exit_code)
endfunction

function! PLURALSIGHT_DownloadComplete(job_id, exit_code)
  if a:exit_code == 0
    echo "Successfully downloaded activity insights binary"
    call s:Register()
  else
    echo "There was a problem downloading the activity insights binary, if the problem persists please contact support"
  endif
endfunction

function! PLURALSIGHT_NVIM_DownloadComplete(job_id, exit_code, event)
  call PLURALSIGHT_DownloadComplete(a:event, a:exit_code)
endfunction

function! s:DownloadBinary()
  if g:is_osx
    let l:os = 'mac'
  elseif g:is_unix
    let l:os = 'linux'
  else
    let l:os = 'windows'
  endif

  let l:curl = 'curl -fLo ~/.pluralsight/activity-insights --create-dirs https://ps-cdn.s3-us-west-2.amazonaws.com/learner-workflow/ps-time/' . l:os . '/ps-time && chmod +x ~/.pluralsight/activity-insights'

  let answer = confirm("Download Pluralsight Activity Insights binary with the following command?\n" . l:curl . "\n", "&Yes\n&No", 2)

  if answer == 1
    execute '!' . l:curl
    call s:Register()
  else
    echo "You can always activate this plugin by running :PluralsightRegister"
  endif
endfunction


function! s:Register()
  if s:IsRegistered()
    echo 'Already successfully registered'
    return
  endif

  if filereadable(g:binary_path)
    if g:is_neovim
      let job = jobstart([g:binary_path, 'register'], {'on_exit': 'PLURALSIGHT_NVIM_RegisterComplete'})
    else
      let job = job_start([g:binary_path, 'register'], {'out_io': 'buffer', 'out_name': 'tosText', 'exit_cb': 'PLURALSIGHT_RegisterComplete'})
    endif
  else
    call s:DownloadBinary()
  endif
endfunction

function! s:Dashboard()
  if g:is_neovim
    let job = jobstart([g:binary_path, 'dashboard'], {'on_exit':  'PLURALSIGHT_NVIM_DashboardCallback'})
  else
    let job = job_start([g:binary_path, 'dashboard'], {'out_io': 'buffer', 'out_name': 'tosText', 'exit_cb': 'PLURALSIGHT_DashboardCallback'})
  endif
endfunction

function! PLURALSIGHT_NVIM_DashboardCallback(job, exit_code, event)
  call s:DashboardCallback(a:job, a:exit_code)
endfunction

function! PLURALSIGHT_DashboardCallback(job, exit_code)
  if a:exit_code == g:TOS_NOT_ACCEPTED_STATUS
    call s:ShowTOS()
  endif
endfunction

function! s:AcceptTOS()
  if g:is_neovim
    let job = jobstart([g:binary_path, 'accept_tos'])
  else
    let job = job_start([g:binary_path, 'accept_tos'])
  endif
  echo "Term of service accepted! Try running the command again"
endfunction

function! s:ShowTOS()
    sbuf tosText
    let timer = timer_start(200, 'PLURALSIGHT_Confirm_TOS')
endfunction

function! PLURALSIGHT_Confirm_TOS(arg)
   let answer = confirm("Do you accept the Pluralsight Terms of Service?\n", "&Yes\n&No", 2)
   bd tosText
   if answer == 1
      call s:AcceptTOS()
   else
      echo "If you don't accept the Terms of Service, the Pluralsight Activity Insights Extension won't work"
   endif
endfunction

call s:Init()


:command! -nargs=0 PluralsightRegister call s:Register()
:command! -nargs=0 PluralsightDashboard call s:Dashboard()
