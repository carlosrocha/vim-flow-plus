
function! s:FlowCoverageHide()
  for match in getmatches()
    if stridx(match['group'], 'FlowCoverage') == 0
      call matchdelete(match['id'])
    endif
  endfor
endfunction

function! GetLine(line)
  return [ get(a:line, 'line'), get(a:line, 'column') ]
endfunction

function! <SID>FlowCoverageRefresh()
  let command = 'flow coverage ' . fnameescape(expand('%')) . ' --from vim --json 2> /dev/null'

  let result = system(command)

  if v:shell_error == 1 || v:shell_error == 3 || len(result) == 0
    let b:flow_coverage_status = ''
    return 0
  endif

  let json_result = json_decode(result)
  let expressions = get(json_result, 'expressions')
  let covered = get(expressions, 'covered_count')
  let uncovered = get(expressions, 'uncovered_count')
  let total = covered + uncovered
  let percent = total > 0 ? ((covered / str2float(total)) * 100.0) : 0.0

  let b:flow_coverage_status = printf('%.2f%% (%d/%d)', percent, covered, total)

  call s:FlowCoverageHide()

  let loclist = []
  for line in get(expressions, 'uncovered_locs')
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
          " TODO: to end of line?
          let each_pos = [each_line, col_start, 100]
        elseif each_line == line_end
          let each_pos = [each_line, 1, col_end]
        else
          let each_pos = each_line
        endif

        call add(positions, each_pos)
      endfor
    endif

    call matchaddpos('FlowCoverage', positions)
    call add(loclist, {
          \ 'lnum': line_start,
          \ 'col': col_start,
          \ 'text': 'Not covered by Flow',
          \ 'valid': 1,
          \ 'type': 'W',
          \})
  endfor

  call setloclist(0, loclist)
endfunction

highlight link FlowCoverage SpellCap

au BufLeave *.js call s:FlowCoverageHide()
au BufWritePost,BufReadPost,BufEnter *.js call <SID>FlowCoverageRefresh()
