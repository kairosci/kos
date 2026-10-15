def widget_id: if type == "string" then . else .id end;
if (.bar | type) != "object" or (.bar.layout | type) != "object" then
  error("Invalid bar layout")
else
  .bar.layout as $layout
  | ["left", "center", "right"] as $sections
  | [$sections[] as $section | ($layout[$section] // [])[]] as $widgets
  | if any($sections[]; (($layout[.] // []) | type) != "array")
      or any($widgets[]; (type != "string" and type != "object") or (widget_id | type) != "string")
      or (($widgets | map(widget_id) | unique | length) != ($widgets | length)) then
      error("Invalid or duplicate bar widgets")
    else
      ($order[0] | [.[][]]) as $managed
      | .bar.layout |= reduce $sections[] as $section (.;
          .[$section] = (
            [$order[0][$section][] as $id | $widgets[] | select(widget_id == $id)]
            + [($layout[$section] // [])[] | select(widget_id as $id | ($managed | index($id)) == null)]
          )
        )
      | .bar.transparent = false
      | if any($widgets[]; widget_id == "omarchy.clock") then .bar.centerAnchor = "omarchy.clock" else . end
    end
end
