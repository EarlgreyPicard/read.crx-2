class SettingIO
  importFile: ""
  constructor: ({
    name: @name
    importFunc: @importFunc
    exportFunc: @exportFunc
  }) ->
    @$status = $$.I("#{@name}_status")
    if @importFunc?
      @$fileSelectButton = $$.C("#{@name}_file_show")[0]
      @$fileSelectButtonHidden = $$.C("#{@name}_file_hide")[0]
      @$importButton = $$.C("#{@name}_import_button")[0]
      @setupFileSelectButton()
      @setupImportButton()
    if @exportFunc?
      @$exportButton = $$.C("#{@name}_export_button")[0]
      @setupExportButton()
    return
  setupFileSelectButton: ->
    @$fileSelectButton.on("click", =>
      @$status.setClass("")
      @$fileSelectButtonHidden.click()
      return
    )
    @$fileSelectButtonHidden.on("change", (e) =>
      file = e.target.files
      reader = new FileReader()
      reader.readAsText(file[0])
      reader.onload = =>
        @importFile = reader.result
        @$status.addClass("select")
        @$status.textContent = "ファイル選択完了"
        return
      return
    )
    return
  setupImportButton: ->
    @$importButton.on("click", =>
      if @importFile isnt ""
        @$status.setClass("loading")
        @$status.textContent = "更新中"
        new Promise( (resolve, reject) =>
          @importFunc(@importFile)
          resolve()
          return
        ).then( =>
          @$status.addClass("done")
          @$status.textContent = "インポート完了"
          return
        , ->
          @$status.addClass("fail")
          @$status.textContent = "インポート失敗"
          return
        )
      else
        @$status.addClass("fail")
        @$status.textContent = "ファイルを選択してください"
      return
    )
    return
  setupExportButton: ->
    @$exportButton.on("click", =>
      blob = new Blob([@exportFunc()],{type:"text/plain"})
      $a = $__("a")
      $a.href = URL.createObjectURL(blob)
      $a.setAttr("target", "_blank")
      $a.setAttr("download", "read.crx-2_#{@name}.json")
      $a.click()
      return
    )
    return

class HistoryIO extends SettingIO
  constructor: ({
    name
    countFunc: @countFunc
    importFunc
    exportFunc
    clearFunc: @clearFunc
    clearRangeFunc: @clearRangeFunc
  }) ->
    super({
      name
      importFunc
      exportFunc
    })
    @name = name
    @importFunc = importFunc
    @exportFunc = exportFunc

    @$clearButton = $$.C("#{@name}_clear")[0]
    @$clearRangeButton = $$.C("#{@name}_range_clear")[0]

    @showCount()
    @setupClearButton()
    @setupClearRangeButton()
    return
  showCount: ->
    count = await @countFunc()
    @$status.textContent = "#{count}件"
    return
  setupClearButton: ->
    @$clearButton.on("click", =>
      result = await UI.Dialog("confirm",
        message: "本当に削除しますか？"
      )
      return unless result
      @$clearButton.addClass("hidden")
      @$status.textContent = "削除中"

      try
        await @clearFunc()
        @$status.textContent = "削除完了"
        parent.$$.$("iframe[src=\"/view/#{@name}.html\"]")?.contentWindow.C("view")[0].dispatchEvent(new Event("request_reload"))
      catch
        @$status.textContent = "削除失敗"

      @$clearButton.removeClass("hidden")
      return
    )
    return
  setupClearRangeButton: ->
    @$clearRangeButton.on("click", =>
      result = await UI.Dialog("confirm",
        message: "本当に削除しますか？"
      )
      return unless result
      @$clearRangeButton.addClass("hidden")
      @$status.textContent = "範囲指定削除中"

      try
        await @clearRangeFunc(parseInt($$.C("#{@name}_date_range")[0].value))
        @$status.textContent = "範囲指定削除完了"
        parent.$$.$("iframe[src=\"/view/#{@name}.html\"]")?.contentWindow.C("view")[0].dispatchEvent(new Event("request_reload"))
      catch
        @$status.textContent = "範囲指定削除失敗"

      @$clearRangeButton.removeClass("hidden")
      return
    )
    return
  setupImportButton: ->
    @$importButton.on("click", =>
      if @importFile isnt ""
        @$status.setClass("loading")
        @$status.textContent = "更新中"
        await @importFunc(JSON.parse(@importFile))
        try
          count = await @countFunc()
          @$status.setClass("done")
          @$status.textContent = "#{count}件 インポート完了"
          @$clearButton.removeClass("hidden")
        catch
          @$status.setClass("fail")
          @$status.textContent = "インポート失敗"
      else
        @$status.addClass("fail")
        @$status.textContent = "ファイルを選択してください"
      return
    )
    return
  setupExportButton: ->
    @$exportButton.on("click", =>
      data = await @exportFunc()
      exportText = JSON.stringify(data)
      blob = new Blob([exportText], type: "text/plain")
      $a = $__("a")
      $a.href = URL.createObjectURL(blob)
      $a.setAttr("target", "_blank")
      $a.setAttr("download", "read.crx-2_#{@name}.json")
      $a.click()
      return
    )
    return

app.boot("/view/config.html", ["cache", "bbsmenu"], (Cache, BBSMenu) ->
  $view = document.documentElement

  new app.view.IframeView($view)

  whenClose = ->
    #NG設定
    app.NG.set($view.$("textarea[name=\"ngwords\"]").value)
    #ImageReplaceDat設定
    app.ImageReplaceDat.set($view.$("textarea[name=\"image_replace_dat\"]").value)
    #ReplaceStrTxt設定
    app.ReplaceStrTxt.set($view.$("textarea[name=\"replace_str_txt\"]").value)
    return

  #閉じるボタン
  $view.C("button_close")[0].on("click", ->
    if frameElement
      tmp = type: "request_killme"
      parent.postMessage(JSON.stringify(tmp), location.origin)
    whenClose()
    return
  )

  window.on("unload", ->
    whenClose()
    return
  )

  #掲示板を開いたときに閉じる
  for dom in $view.C("open_in_rcrx")
    dom.on("click", ->
      $view.C("button_close")[0].click()
      return
    )

  #汎用設定項目
  for dom in $view.$$("input.direct[type=\"text\"], textarea.direct")
    dom.value = app.config.get(dom.name) or ""
    dom.on("input", ->
      app.config.set(@name, @value)
      return
    )

  for dom in $view.$$("input.direct[type=\"number\"]")
    dom.value = app.config.get(dom.name) or "0"
    dom.on("input", ->
      app.config.set(@name, if Number.isInteger(+@value) then @value else "0")
      return
    )

  for dom in $view.$$("input.direct[type=\"checkbox\"]")
    dom.checked = app.config.get(dom.name) is "on"
    dom.on("change", ->
      app.config.set(@name, if @checked then "on" else "off")
      return
    )

  for dom in $view.$$("input.direct[type=\"radio\"]")
    if dom.value is app.config.get(dom.name)
      dom.checked = true
    dom.on("change", ->
      val = $view.$("""input[name="#{@name}"]:checked""").value
      app.config.set(@name, val)
      return
    )

  for dom in $view.$$("input.direct[type=\"range\"]")
    dom.value = app.config.get(dom.name) or "0"
    $view.C("#{dom.name}_text")[0].textContent = dom.value
    dom.on("input", ->
      $view.C("#{@name}_text")[0].textContent = @value
      app.config.set(@name, @value)
      return
    )

  #バージョン情報表示
  $view.C("version_text")[0].textContent = "#{app.manifest.name} v#{app.manifest.version} + #{navigator.userAgent}"

  $view.C("version_copy")[0].on("click", ->
    app.clipboardWrite($$.C("version_text")[0].textContent)
    return
  )

  $view.C("keyboard_help")[0].on("click", (e) ->
    e.preventDefault()

    app.message.send("showKeyboardHelp")
    return
  )

  #忍法帖関連機能
  do ->
    $ninjaInfo = $view.C("ninja_info")[0]

    updateNinjaInfo = ->
      app.Ninja.getCookie( (cookies) ->
        $ninjaInfo.removeChildren()

        backup = app.Ninja.getBackup()

        data = {}

        for item in cookies
          data[item.site.siteId] =
            site: item.site
            hasCookie: true
            hasBackup: false

        for item in backup
          if data[item.site.siteId]?
            data[item.site.siteId].hasBackup = true
          else
            data[item.site.siteId] =
              site: item.site
              hasCookie: false
              hasBackup: true

        for siteId, item of data
          $div = $$.I("template_ninja_item").content.$(".ninja_item").cloneNode(true)

          $div.dataset.siteid = item.site.siteId
          $div.C("site_name")[0].textContent = item.site.siteName

          if item.hasCookie
            $div.addClass("ninja_item_cookie_found")

          if item.hasBackup
            $div.addClass("ninja_item_backup_available")

          $ninjaInfo.addLast($div)
        return
      )
      return

    updateNinjaInfo()

    # 「Cookieを削除」ボタン
    $ninjaInfo.on("click", ({target}) ->
      return unless target.matches(".ninja_item_cookie_found > button")
      siteId = target.closest(".ninja_item").dataset.siteid
      app.Ninja.deleteCookie(siteId, updateNinjaInfo)
      return
    )

    # 「バックアップから復元」ボタン
    $ninjaInfo.on("click", ({target}) ->
      return unless target.matches(".ninja_item_cookie_notfound > button")
      siteId = target.closest(".ninja_item").dataset.siteid
      app.Ninja.restore(siteId, updateNinjaInfo)
      return
    )

    # 「バックアップを削除」ボタン
    $ninjaInfo.on("click", ({target}) ->
      return unless target.matches(".ninja_item_backup_available > button")
      siteId = target.closest(".ninja_item").dataset.siteid
      UI.Dialog("confirm",
        message: "本当に削除しますか？"
      ).then( (result) ->
        return unless result
        app.Ninja.deleteBackup(siteId)
        updateNinjaInfo()
        return
      )
      return
    )
    return

  #板覧更新ボタン
  $view.C("bbsmenu_reload")[0].on("click", ({currentTarget: $button}) ->
    $status = $$.I("bbsmenu_reload_status")

    $button.disabled = true
    $status.setClass("loading")
    $status.textContent = "更新中"

    BBSMenu.get( (res) ->
      $button.disabled = false
      if res.status is "success"
        $status.setClass("done")
        $status.textContent = "更新完了"

        # sidemenuの表示時に設定されたコールバックが実行されるので、特別なことはしない
      else
        $status.setClass("fail")
        $status.textContent = "更新失敗"
      return
    , true)
    return
  )

  #履歴
  new HistoryIO(
    name: "history"
    countFunc: ->
      return app.History.count()
    importFunc: (inputObj) ->
      return Promise.all(
        inputObj.history.map( (his) ->
          return app.History.add(his.url, his.title, his.date)
        ).concat(inputObj.read_state.map( (rs) ->
          return app.ReadState.set(rs)
        ))
      )
    exportFunc: ->
      return Promise.all([
        app.ReadState.getAll(),
        app.History.getAll()
      ]).then( ([read_state_res, history_res]) ->
        return {"read_state": read_state_res, "history": history_res}
      )
    clearFunc: ->
      return Promise.all([app.History.clear(), app.ReadState.clear()])
    clearRangeFunc: (day) ->
      return app.History.clearRange(day)
  )

  new HistoryIO(
    name: "writehistory"
    countFunc: ->
      return app.WriteHistory.count()
    importFunc: (inputObj) ->
      if inputObj.writehistory
        return Promise.all(inputObj.writehistory.map( (whis) ->
          return app.WriteHistory.add(whis.url, whis.res, whis.title, whis.name, whis.mail, whis.input_name, whis.input_mail, whis.message, whis.date)
        ))
      else
        return Promise.resolve()
    exportFunc: ->
      return app.WriteHistory.getAll().then( (data) ->
        return {"writehistory": data}
      )
    clearFunc: ->
      return app.WriteHistory.clear()
    clearRangeFunc: (day) ->
      return app.WriteHistory.clearRange(day)
  )

  do ->
    #キャッシュ削除ボタン
    $clearButton = $view.C("cache_clear")[0]
    $status = $$.I("cache_status")

    do ->
      count = await Cache.count()
      $status.textContent = "#{count}件"
      return

    $clearButton.on("click", ->
      $clearButton.remove()
      $status.textContent = "削除中"

      try
        await Cache.delete()
        $status.textContent = "削除完了"
      catch
        $status.textContent = "削除失敗"
      return
    )
    #キャッシュ範囲削除ボタン
    $clearRangeButton = $view.C("cache_range_clear")[0]
    $clearRangeButton.on("click", ->
      $status.textContent = "範囲指定削除中"

      try
        await Cache.clearRange(parseInt($view.C("cache_date_range")[0].value))
        $status.textContent = "削除完了"
      catch
        $status.textContent = "削除失敗"
      return
    )
    return

  do ->
    #ブックマークフォルダ変更ボタン
    $view.C("bookmark_source_change")[0].on("click", ->
      app.message.send("open", url: "bookmark_source_selector")
      return
    )

    #ブックマークフォルダ表示
    do updateName = ->
      chrome.bookmarks.get(app.config.get("bookmark_id"), ([folder]) ->
        $$.I("bookmark_source_name").textContent = folder.title
        return
      )
    app.message.on("config_updated", (message) ->
      updateName() if message.key is "bookmark_id"
      return
    )
    return

  #ブックマークインポートボタン
  $view.C("import_bookmark")[0].on("click", ({currentTarget: $button}) ->
    rcrx_webstore = "hhjpdicibjffnpggdiecaimdgdghainl"
    rcrx_debug = "bhffdiookpgmjkaeiagoecflopbnphhi"
    req = "export_bookmark"

    $status = $$.I("import_bookmark_status")

    $button.disabled = true
    $status.textContent = "インポート中"

    new Promise( (resolve, reject) ->
      parent.chrome.runtime.sendMessage(rcrx_webstore, req, (res) ->
        if res
          resolve(res)
        else
          reject()
        return
      )
      return
    ).catch( ->
      return new Promise( (resolve, reject) ->
        parent.chrome.runtime.sendMessage(rcrx_debug, req, (res) ->
          if res
            resolve(res)
          else
            reject()
          return
        )
        return
      )
    ).then( (res) ->
      for url, bookmark of res.bookmark when typeof(url) is typeof(bookmark.title) is "string"
        app.bookmark.add(url, bookmark.title)
      for url, bookmark of res.bookmark_board when typeof(url) is typeof(bookmark.title) is "string"
        app.bookmark.add(url, bookmark.title)
      $status.textContent = "インポート完了"
      return
    , ->
      $status.textContent = "インポートに失敗しました。read.crx v0.73以降がインストールされている事を確認して下さい。"
      return
    ).then( ->
      $button.disabled = false
      return
    )
    return
  )

  #「テーマなし」設定
  if app.config.get("theme_id") is "none"
    $view.C("theme_none")[0].checked = true

  app.message.on("config_updated", (message) ->
    if message.key is "theme_id"
      $view.C("theme_none")[0].checked = (message.val is "none")
    return
  )

  $view.C("theme_none")[0].on("click", ->
    app.config.set("theme_id", if @checked then "none" else "default")
    return
  )

  #bbsmenu設定
  resetBBSMenu = ->
    await app.config.del("bbsmenu")
    $view.$(".direct.bbsmenu").value = app.config.get("bbsmenu")
    $$.C("bbsmenu_reload")[0].click()
    return

  if $view.$(".direct.bbsmenu").value is ""
    resetBBSMenu()

  $view.$(".direct.bbsmenu").on("change", ->
    if $view.$(".direct.bbsmenu").value isnt ""
      $$.C("bbsmenu_reload")[0].click()
    else
      resetBBSMenu()
    return
  )

  $view.C("bbsmenu_reset")[0].on("click", ->
    resetBBSMenu()
    return
  )

  # 設定をインポート/エクスポート
  new SettingIO(
    name: "config"
    importFunc: (file) ->
      json = JSON.parse(file)
      for key, value of json
        key = key.slice(7)
        if key isnt "theme_id"
          $key = $view.$("input[name=\"#{key}\"]")
          if $key?
            switch $key.getAttr("type")
              when "text", "range", "number"
                $key.value = value
                $key.dispatchEvent(new Event("input"))
              when "checkbox"
                $key.checked = (value is "on")
                $key.dispatchEvent(new Event("change"))
              when "radio"
                $key.value = value
                $key.dispatchEvent(new Event("change"))
          else
            $keyTextArea = $view.$("textarea[name=\"#{key}\"]")
            if $keyTextArea?
              $keyTextArea.value = value
              $keyTextArea.dispatchEvent(new Event("input"))
         #config_theme_idは「テーマなし」の場合があるので特例化
         else
           if value is "none"
             $theme_none = $view.C("theme_none")[0]
             $theme_none.click() unless $theme_none.checked
           else
             $view.$("input[name=\"theme_id\"]").value = value
             $view.$("input[name=\"theme_id\"]").dispatchEvent(new Event("change"))
      return
    exportFunc: ->
      content = app.config.getAll()
        .replace(/"config_last_board_sort_config":".*?","/,"\"")
        .replace(/"config_last_version":".*?","/,"\"")
      return content
  )

  # ImageReplaceDatをインポート
  new SettingIO(
    name: "dat"
    importFunc: (file) ->
      datDom = $view.$("textarea[name=\"image_replace_dat\"]")
      datDom.value = file
      datDom.dispatchEvent(new Event("input"))
      return
  )

  # ReplaceStrTxtをインポート
  new SettingIO(
    name: "replacestr"
    importFunc: (file) ->
      replacestrDom = $view.$("textarea[name=\"replace_str_txt\"]")
      replacestrDom.value = file
      replacestrDom.dispatchEvent(new Event("input"))
      return
  )

  #過去の履歴をインポート
  $replacestrStatus = $$.I("history_from_1151_status")
  $view.C("history_from_1151")[0].on( "click", ->
    $replacestrStatus.setClass("loading")
    $replacestrStatus.textContent = "インポート中"
    hisPro = new Promise( (resolve, reject) ->
      openDatabase("History", "", "History", 0).transaction( (tx) ->
        tx.executeSql("SELECT * FROM History", [], (t, his) ->
          h = Array.from(his.rows)
          h.map( ({url, title, date}) ->
            return app.History.add(url, title, date)
          )
          try
            await Promise.all(h)
            t.executeSql("drop table History", [])
            resolve()
          catch e
            reject(e)
          return
        , (e) ->
          if e.code?
            reject(e)
          else
            resolve()
          return
        )
      )
    )
    whisPro = new Promise( (resolve, reject) ->
      openDatabase("WriteHistory", "", "WriteHistory", 0).transaction( (tx) ->
        tx.executeSql("SELECT * FROM WriteHistory", [], (t, whis) ->
          w = Array.from(whis.rows)
          w.map( ({url, res, title, name, mail, input_name, message, date}) ->
            return app.WriteHistory.add(url, res, title, name, mail, input_name, mail, message, date)
          )
          try
            await Promise.all(w)
            t.executeSql("drop table WriteHistory", [])
            resolve()
          catch e
            reject(e)
          return
        , (e) ->
          if e.code?
            reject(e)
          else
            resolve()
          return
        )
      )
    )
    rsPro = new Promise( (resolve, reject) ->
      openDatabase("ReadState", "", "Read State", 0).transaction( (tx) ->
        tx.executeSql("SELECT * FROM ReadState", [], (t, rs) ->
          r = Array.from(rs.rows)
          r.map( (a) ->
            return app.ReadState.set(a)
          )
          try
            await Promise.all(r)
            t.executeSql("drop table ReadState", [])
            resolve()
          catch e
            reject(e)
          return
        , (e) ->
          if e.code?
            reject(e)
          else
            resolve()
          return
        )
      )
    )
    try
      await Promise.all([hisPro, whisPro, rsPro])
      $replacestrStatus.addClass("done")
      $replacestrStatus.textContent = "インポート完了"
    catch e
      $replacestrStatus.addClass("fail")
      $replacestrStatus.textContent = "インポート失敗 - #{e}"
    return
  )
  return
)
