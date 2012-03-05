(($) ->
  $root = null

  popup_destroy = ($popup) ->
    $popup.find(".popup").andSelf()
      .each ->
        $($(@).data("popup_source"))
          .unbind("mouseleave", on_mouseenter)
          .unbind("mouseenter", on_mouseleave)
    $popup.remove()

  remove = ->
    return unless $root
    $root.find(".popup").andSelf().filter(":not(.active)")
      .each ->
        $this = $(@)
        if $this.has(".popup.active").length is 0
          $root = null if $this.is($root)
          popup_destroy($this)

  on_mouseenter = ->
    $this = $(@)
    $popup = if $this.is(".popup") then $this else $($this.data("popup"))
    $popup.addClass("active")
    return

  on_mouseleave = ->
    $this = $(@)
    $popup = if $this.is(".popup") then $this else $($this.data("popup"))
    $popup.removeClass("active")
    setTimeout(remove, 300)
    return

  $.popup = (default_parent, popup, mouse_x, mouse_y, source) ->
    $popup = $(popup)
    $popup
      .addClass("popup active")
      .data("popup_source", source)

    #.popup内にsourceが有った場合はネスト
    #そうでなければ、指定されたデフォルトの要素に追加
    $parent = $(source).closest(".popup")
    if $parent.length is 1
      $parent.append($popup)
    else
      popup_destroy($root) if $root
      $root = $popup
      $(default_parent).append($popup)

    #同一ソースからのポップアップが既に有る場合は、処理を中断
    flg = false
    $popup.siblings(".popup").each ->
      flg or= $($(this).data("popup_source")).is(source)
      null
    if flg
      $popup.remove()
      return

    #兄弟ノードの削除
    $parent.children(".popup").each ->
      if not ($this = $(@)).is($popup)
        popup_destroy($this)

    #表示位置決定
    do ->
      margin = 20

      #カーソルの上下左右のスペースを測定
      space =
        left: mouse_x
        right: document.body.offsetWidth - mouse_x
        top: mouse_y
        bottom: document.body.offsetHeight - mouse_y

      #通常はカーソル左か右のスペースを用いるが、そのどちらもが狭い場合は上下に配置する
      if Math.max(space.left, space.right) > 400
        #例え右より左が広くても、右に十分なスペースが有れば右に配置
        if space.right > 350
          $popup.css("left", "#{space.left + margin}px")
          $popup.css("max-width", document.body.offsetWidth - space.left - margin * 2)
        else
          $popup.css("right", "#{space.right + margin}px")
          $popup.css("max-width", document.body.offsetWidth - space.right - margin * 2)
        $popup.css("top", "#{Math.min(space.top, document.body.offsetHeight - $popup.outerHeight()) - margin}px")
      else
        #例え上より下が広くても、上に十分なスペースが有れば上に配置
        if space.top > Math.min(250, space.bottom)
          $popup.css("bottom", space.bottom + margin)
        else
          $popup.css("top", document.body.offsetHeight - space.bottom + margin)
        $popup.css("left", margin)
        $popup.css("max-width", document.body.offsetWidth - margin * 2)
      return

    $(source)
      .data("popup", $popup[0])
      .add($popup)
        .bind("mouseenter", on_mouseenter)
        .bind("mouseleave", on_mouseleave)

)(jQuery)

