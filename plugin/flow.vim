" vint: -ProhibitImplicitScopeVariable

if exists('g:loaded_flow_coverage')
  finish
endif
let g:loaded_flow_coverage = 1

let w:flow_coverage_highlight_enabled = 1

function! s:FlowCoverageHide()
  if exists('w:current_highlights')
    for l:highlight in w:current_highlights
      call matchdelete(l:highlight)
    endfor
  endif
  let w:current_highlights = []
  let w:highlights_drawn = 0
endfunction

function! GetLine(line)
  return [ get(a:line, 'line'), get(a:line, 'column') ]
endfunction

let g:flow#flowpath = 'flow'
let g:flow#flags = ' --from vim --json --no-auto-start --strip-root'

function! s:FlowCoverageRefresh()
  let command = g:flow#flowpath . ' coverage ' . g:flow#flags
  let stdin = getline(1, '$')
  let result = system(command, stdin)

  if v:shell_error > 0 || empty(result)
    let b:flow_coverage_status = ''
    return
  endif

  let json_result = json_decode(result)
  let expressions = get(json_result, 'expressions')
  let covered = get(expressions, 'covered_count')
  let total = covered + get(expressions, 'uncovered_count')
  let percent = total > 0 ? ((covered / str2float(total)) * 100.0) : 0.0

  let b:flow_coverage_status = printf('%.2f%% (%d/%d)', percent, covered, total)
  let b:flow_coverage_uncovered_locs = get(expressions, 'uncovered_locs')

  if w:flow_coverage_highlight_enabled
    call s:FlowCoverageShowHighlights()
  endif
endfunction

function! s:FlowCoverageShowHighlights()
  if !exists('b:flow_coverage_uncovered_locs')
    call s:FlowCoverageRefresh()
  endif

  call s:FlowCoverageHide()

  for line in b:flow_coverage_uncovered_locs
    let [line_start, col_start] = GetLine(get(line, 'start'))
    let [line_end, col_end] = GetLine(get(line, 'end'))

    if line_start == line_end
      let positions = [[line_start, col_start, col_end - col_start + 1]]
    else
      let positions = []
      for each_line in range(line_start, line_end)
        if each_line == line_start
          let each_pos = [each_line, col_start, 100]
        elseif each_line == line_end
          let each_pos = [each_line, 1, col_end]
        else
          let each_pos = each_line
        endif

        call add(positions, each_pos)
      endfor
    endif

    call add(w:current_highlights, matchaddpos('FlowCoverage', positions))
  endfor
  let w:highlights_drawn = 1
endfunction

function! s:ToggleHighlight()
  if !exists('w:highlights_drawn')
    return
  endif
  if w:highlights_drawn && w:flow_coverage_highlight_enabled
    let w:flow_coverage_highlight_enabled = 0
    call s:FlowCoverageHide()
  else
    let w:flow_coverage_highlight_enabled = 1
    call s:FlowCoverageShowHighlights()
  endif
endfunction

function! s:FindRefs(pos) abort
  if exists('b:flow_current_refs')
    unlet b:flow_current_refs
  endif

  let command = g:flow#flowpath . ' find-refs ' . a:pos . g:flow#flags
  let result = system(command, getline(1, '$'))

  if v:shell_error > 0 || empty(result)
    if v:shell_error == 6
      echom 'Flow: Server not running'
    endif
    return
  endif

  let b:flow_current_refs = json_decode(result)
endfunction

function! s:NextRef(delta) abort
  let pos = line('.') . ' ' . col('.')

  if !exists('b:flow_refs_last_jump') || pos != b:flow_refs_last_jump ||
        \ !exists('b:flow_current_refs')
    call s:FindRefs(pos)
    if !exists('b:flow_current_refs')
      return
    endif
  endif

  let refs_len = len(b:flow_current_refs)
  let offset = line2byte(line('.')) + col('.') - 2
  let idx = Search(offset, b:flow_current_refs)

  if idx > -1
    let next_ref_idx = idx + (a:delta)
    if next_ref_idx < 0 || next_ref_idx >= refs_len
      let next_ref_idx = float2nr(fmod(next_ref_idx, refs_len))
    endif

    let next_ref = get(b:flow_current_refs, next_ref_idx)
    let next_ref_start = get(next_ref, 'start')
    let [line, column] = GetLine(next_ref_start)

    " Save last jump to reuse the refs
    let b:flow_refs_last_jump = line . ' ' . column
    call cursor(line, column)
  else
    echom 'Flow: No references found'
  endif
endfunction

function! Search(value, list)
  let min_index = 0
  let max_index = len(a:list) - 1

  while min_index <= max_index
    let curr_index = float2nr((min_index + max_index) / 2)
    let curr_el = get(a:list, curr_index)
    let offset_start = get(curr_el['start'], 'offset')
    let offset_end = get(curr_el['end'], 'offset')

    if offset_start <= a:value && offset_end >= a:value
      return curr_index
    elseif offset_start < a:value
      let min_index = curr_index + 1
    else
      let max_index = curr_index - 1
    endif
  endwhile

  return -1
endfunction

command! FlowCoverageToggle call s:ToggleHighlight()
command! FlowNextRef call s:NextRef(1)
command! FlowPrevRef call s:NextRef(-1)

highlight link FlowCoverage SpellCap

au BufLeave *.js call s:FlowCoverageHide()
au BufWritePost,BufReadPost,BufEnter *.js call s:FlowCoverageRefresh()
