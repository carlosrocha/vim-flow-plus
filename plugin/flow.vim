
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

function! s:FlowCoverageRefresh()
  let filename = fnameescape(expand('%'))
  let command = 'flow coverage ' . filename . ' --from vim --json 2> /dev/null'

  let result = system(command)

  if v:shell_error == 1 || v:shell_error == 3 || len(result) == 0
    let b:flow_coverage_status = ''
    return
  endif

  let json_result = json_decode(result)
  let expressions = get(json_result, 'expressions')
  let covered = get(expressions, 'covered_count')
  let uncovered = get(expressions, 'uncovered_count')
  let total = covered + uncovered
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
    let start = get(line, 'start')
    let end = get(line, 'end')
    let [line_start, col_start] = GetLine(start)
    let [line_end, col_end] = GetLine(end)

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

function! s:FlowCoverageToggleHighlight()
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

command FlowCoverageToggle call s:FlowCoverageToggleHighlight()

highlight link FlowCoverage SpellCap

au BufLeave *.js call s:FlowCoverageHide()
au BufWritePost,BufReadPost,BufEnter *.js call s:FlowCoverageRefresh()
