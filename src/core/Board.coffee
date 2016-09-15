###*
@namespace app
@class Board
@constructor
@param {String} url
@requires jQuery
@requires app.Cache
@requires app.NG
###
class app.Board
  constructor: (@url) ->
    ###*
    @property thread
    @type Array | null
    ###
    @thread = null

    ###*
    @property message
    @type String | null
    ###
    @message = null
    return

  ###*
  @method get
  @return {Promise}
  ###
  get: ->
    res_deferred = $.Deferred()

    tmp = Board._get_xhr_info(@url)
    unless tmp
      return res_deferred.reject().promise()
    xhr_path = tmp.path
    xhr_charset = tmp.charset

    #キャッシュ取得
    cache = new app.Cache(xhr_path)
    cache_get_promise = cache.get()
    cache_get_promise.then ->
      $.Deferred (d) ->
        if Date.now() - cache.last_updated < 1000 * 3
          d.resolve()
        else
          d.reject()
        return
    #通信
    .then null, =>
      $.Deferred (d) ->
        request = new app.HTTP.Request("GET", xhr_path, {
          mimeType: "text/plain; charset=#{xhr_charset}"
        })

        if cache_get_promise.state() is "resolved"
          if cache.last_modified?
            request.headers["If-Modified-Since"] =
              new Date(cache.last_modified).toUTCString()
          if cache.etag?
            request.headers["If-None-Match"] = cache.etag

        request.send (response) ->
          if response.status is 200
            d.resolve(response)
          else if cache_get_promise.state() is "resolved" and response.status is 304
            d.resolve(response)
          else
            d.reject(response)
        return
    #パース
    .then((fn = (response) =>
      $.Deferred (d) =>
        if response?.status is 200
          thread_list = Board.parse(@url, response.body)
        else if cache_get_promise.state() is "resolved"
          thread_list = Board.parse(@url, cache.data)

        if thread_list?
          if response?.status is 200 or response?.status is 304 or (not response? and cache_get_promise.state() is "resolved")
            d.resolve(response, thread_list)
          else
            d.reject(response, thread_list)
        else
          d.reject(response)
        return
    ), fn)
    #コールバック
    .done (response, thread_list) =>
      @thread = thread_list
      res_deferred.resolve()
      return

    .fail (response, thread_list) =>
      @message = "板の読み込みに失敗しました。"

      #2chでrejectされている場合は移転を疑う
      if app.url.tsld(@url) is "2ch.net" and response?
        app.util.ch_server_move_detect(@url)
          #移転検出時
          .done (new_board_url) =>
            @message += """
            サーバーが移転している可能性が有ります
            (<a href="#{app.escape_html(app.safe_href(new_board_url))}"
            class="open_in_rcrx">#{app.escape_html(new_board_url)}
            </a>)
            """
          .always =>
            if cache_get_promise.state() is "resolved" and thread_list?
              @message += "キャッシュに残っていたデータを表示します。"

            if thread_list
              @thread = thread_list
      else
        if cache_get_promise.state() is "resolved" and thread_list?
          @message += "キャッシュに残っていたデータを表示します。"

        if thread_list?
          @thread = thread_list
      res_deferred.reject()
      return
    #キャッシュ更新部
    .done (response, thread_list) ->
      if response?.status is 200
        cache.data = response.body
        cache.last_updated = Date.now()

        last_modified = new Date(
          response.headers["Last-Modified"] or "dummy"
        ).getTime()

        if not isNaN(last_modified)
          cache.last_modified = last_modified

        if etag = response.headers["ETag"]
          cache.etag = etag

        cache.put()

        for thread in thread_list
          app.bookmark.update_res_count(thread.url, thread.res_count)

      else if cache_get_promise.state() is "resolved" and response?.status is 304
        cache.last_updated = Date.now()
        cache.put()
      return
    #dat落ちスキャン
    .done (response, thread_list) =>
      if thread_list
        dict = {}
        for bookmark in app.bookmark.get_by_board(@url) when bookmark.type is "thread"
          dict[bookmark.url] = true

        for thread in thread_list when dict[thread.url]?
          delete dict[thread.url]
          app.bookmark.update_expired(thread.url, false)

        for thread_url of dict
          app.bookmark.update_expired(thread_url, true)
      return
    res_deferred.promise()

  ###*
  @method _get_xhr_info
  @private
  @static
  @param {String} board_url
  @return {Object | null} xhr_info
  ###
  @_get_xhr_info: (board_url) ->
    tmp = ///^http://((?:\w+\.)?(\w+\.\w+))/(\w+)/(?:(\d+)/)?$///.exec(board_url)
    unless tmp
      return null
    switch tmp[2]
      when "machi.to"
        path: "http://#{tmp[1]}/bbs/offlaw.cgi/#{tmp[3]}/"
        charset: "Shift_JIS"
      when "livedoor.jp", "shitaraba.net"
        path: "http://jbbs.shitaraba.net/#{tmp[3]}/#{tmp[4]}/subject.txt"
        charset: "EUC-JP"
      else
        path: "http://#{tmp[1]}/#{tmp[3]}/subject.txt"
        charset: "Shift_JIS"

  ###*
  @method parse
  @static
  @param {String} url
  @param {String} text
  @return {Array | null} board
  ###
  @parse: (url, text) ->
    tmp = /^http:\/\/((?:\w+\.)?(\w+\.\w+))\/(\w+)\/(\w+)?/.exec(url)
    switch tmp[2]
      when "machi.to"
        bbs_type = "machi"
        reg = /^\d+<>(\d+)<>(.+)\((\d+)\)$/gm
        base_url = "http://#{tmp[1]}/bbs/read.cgi/#{tmp[3]}/"
      when "shitaraba.net"
        bbs_type = "jbbs"
        reg = /^(\d+)\.cgi,(.+)\((\d+)\)$/gm
        base_url = "http://jbbs.shitaraba.net/bbs/read.cgi/#{tmp[3]}/#{tmp[4]}/"
      else
        bbs_type = "2ch"
        reg = /^(\d+)\.dat<>(.+) \((\d+)\)$/gm
        base_url = "http://#{tmp[1]}/test/read.cgi/#{tmp[3]}/"

    ng = app.NG.get()
    needlessReg = /.+\.2ch\.netの人気スレ|【漫画あり】コンビニで浪人を購入する方法|★★ ２ちゃんねる\(sc\)のご案内 ★★★|浪人はこんなに便利/

    board = []
    while (reg_res = reg.exec(text))
      title = app.util.decode_char_reference(reg_res[2])
      title = app.util.removeNeedlessFromTitle(title)
      tmpTitle = app.util.normalize(title)

      board.push(
        url: base_url + reg_res[1] + "/"
        title: title
        res_count: +reg_res[3]
        created_at: +reg_res[1] * 1000
        ng: do (title, ng) ->
          for n in ng
            if (
              (n.type is "regExp" and n.reg.test(title)) or
              (n.type is "regExpTitle" and n.reg.test(title)) or
              (n.type is "title" and tmpTitle.includes(n.word)) or
              (n.type is "word" and tmpTitle.includes(n.word))
            )
              return true
          return false
        need_less: needlessReg.test(title)
        is_net: !title.startsWith("★")
      )

    if bbs_type is "jbbs"
      board.splice(-1, 1)

    if board.length > 0 then board else null

  ###*
  @method get_cached_res_count
  @static
  @param {String} thread_url
  @return {Promise}
  ###
  @get_cached_res_count: (thread_url) ->
    board_url = app.url.thread_to_board(thread_url)
    xhr_path = Board._get_xhr_info(board_url)?.path

    unless xhr_path?
      return $.Deferred().reject().promise()

    cache = new app.Cache(xhr_path)
    cache.get().then =>
      $.Deferred (d) =>
        last_modified = cache.last_modified
        for thread in Board.parse(board_url, cache.data) when thread.url is thread_url
          d.resolve
            res_count: thread.res_count
            modified: last_modified
          return
        d.reject()
        return
    .promise()

app.module "board", [], (callback) ->
  callback(app.Board)
  return

app.board =
  get: (url, callback) ->
    board = new app.Board(url)
    board.get()
      .done ->
        callback(status: "success", data: board.thread)
        return
      .fail ->
        tmp = {status: "error"}
        if board.message?
          tmp.message = board.message
        if board.thread?
          tmp.data = board.thread
        callback(tmp)
        return
    return

  get_cached_res_count: (thread_url, callback) ->
    app.Board.get_cached_res_count(thread_url)
      .done (res) ->
        callback(res)
        return
      .fail ->
        callback(null)
        return
    return