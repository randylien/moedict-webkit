const DEBUGGING = no

LANG = getPref(\lang) || (if document.URL is /twblg/ then \t else \a)
MOE-ID = getPref(\prev-id) || {a: \萌 t: \發穎 h: \發芽}[LANG]
$ -> $('body').addClass("lang-#LANG")

isCordova = document.URL isnt /^https?:/
isDeviceReady = not isCordova
isCordova = true if DEBUGGING
isMobile = isCordova or navigator.userAgent is /Android|iPhone|iPad|Mobile/
isWebKit = navigator.userAgent is /WebKit/
entryHistory = []
Index = null

try
  throw unless isCordova and not DEBUGGING
  document.addEventListener \deviceready (->
    try navigator.splashscreen.hide!
    isDeviceReady := yes
    window.do-load!
  ), false
catch
  <- $
  $ \#F9868 .html '&#xF9868;'
  $ \#loading .text \載入中，請稍候…
  if document.URL is /http:\/\/(?:www.)?moedict.tw/i
    url = "https://www.moedict.tw/"
    url += location.hash if location.hash is /^#./
    location.replace url
  else
    window.do-load!
    if navigator.user-agent is /MSIE\s+[678]/
      <- $.getScript \https://ajax.googleapis.com/ajax/libs/chrome-frame/1/CFInstall.min.js
      window.gcfnConfig = do
        imgpath: 'https://raw.github.com/atomantic/jquery.ChromeFrameNotify/master/img/'
        msgPre: ''
        msgLink: '敬請安裝 Google 內嵌瀏覽框，以取得更完整的萌典功能。'
        msgAfter: ''
      <- $.getScript \https://raw.github.com/atomantic/jquery.ChromeFrameNotify/master/jquery.gcnotify.min.js

function setPref (k, v) => try localStorage?setItem(k, JSON?stringify(v))
function getPref (k) => try JSON?parse(localStorage?getItem(k) ? \null)

window.show-info = ->
  ref = window.open \Android.html \_blank \location=no
  on-stop = ({url}) -> ref.close! if url is /quit\.html/
  on-exit = ->
    ref.removeEventListener \loadstop on-stop
    ref.removeEventListener \exit     on-exit
  ref.addEventListener \loadstop on-stop
  ref.addEventListener \exit     on-exit

callLater = -> setTimeout it, if isMobile then 10ms else 1ms

window.press-lang = (lang='', id='') ->
  $('body').removeClass("lang-t")
  $('.ui-autocomplete li').remove!
  LANG := lang || (if LANG is \a then \t else \a)
  $.get "#LANG/index.json", null, (->
    init-autocomplete it
    $('body').addClass("lang-#LANG")
    $ \#query .val id
    window.do-lookup(id || {a: \萌 t: \發穎 h: \發芽}[LANG])
    setPref \lang LANG
  ), \text

window.press-down = ->
  if navigator.user-agent is /Android\s*[12]\./
    alert "抱歉，Android 2.x 版僅能於上方顯示搜尋框。"
    return
  $('body').removeClass "prefer-down-#{ !!getPref \prefer-down }"
  val = !getPref \prefer-down
  setPref \prefer-down val
  $('body').addClass "prefer-down-#{ !!getPref \prefer-down }"

window.do-load = ->
  return unless isDeviceReady
  $('body').addClass \cordova if isCordova
  $('body').addClass \web unless isCordova
  $('body').addClass \ios if isCordova and location.href isnt /android_asset/
  $('body').addClass \android if isCordova and location.href is /android_asset/
  if navigator.user-agent is /Android\s*[12]\./
    $('body').addClass \overflow-scrolling-false
    $('body').addClass "prefer-down-false"
  else
    $('body').addClass "prefer-down-#{ !!getPref \prefer-down }"
  $('#result').addClass "prefer-pinyin-#{ !!getPref \prefer-pinyin }"

  fontSize = getPref(\font-size) || 14
  $('body').bind \pinch (, {scale}) ->
    $('body').css('font-size', Math.max(14, Math.min(22, (scale * fontSize))) + 'pt')
  saveFontSize = (, {scale}) ->
    setPref \font-size fontSize := Math.max(14, Math.min(22, (scale * fontSize)))
    $('body').css('font-size', fontSize + 'pt')
  $('body').bind \pinchclose saveFontSize
  $('body').bind \pinchopen saveFontSize
  window.adjust-font-size = (offset) ->
    setPref \font-size fontSize := Math.max(14, Math.min(22, (fontSize + offset)))
    $('body').css('font-size', fontSize + 'pt')
  window.adjust-font-size 0

  cache-loading = no
  window.press-about = press-about = ->
    location.href = \about.html unless location.href is /android_asset/
  window.press-erase = press-erase = ->
    $ \#query .val '' .focus!
    $ \.lang .show!
    $ \.erase .hide!
  window.press-back = press-back = ->
    return if cache-loading
    entryHistory.pop!
    token = Math.random!
    cache-loading := token
    setTimeout (-> cache-loading := no if cache-loading is token), 10000ms
    callLater ->
      id = if entryHistory.length then entryHistory[*-1] else MOE-ID
      $ \#query .val id
      $ \#cond .val "^#{id}$"
      fetch id
    return false

  try document.addEventListener \backbutton, (!->
    if entryHistory.length <= 1 then window.press-quit! else window.press-back!
  ), false

  window.press-quit = -> callLater -> navigator.app.exit-app!

  init = ->
    $ \#query .keyup lookup .change lookup .keypress lookup .keydown lookup .on \input lookup
    $ \#query .on \focus -> @select!
    $ \#query .show!
    $ \#query .focus! unless isCordova

    if \onhashchange not in window
      $ \body .on \click \a ->
        val = $(@).attr(\href)
        val -= /.*\#/ if val
        val ||= $(@).text!
        return if val is $ \#query .val!
        $ \#query .val val
        $ \#cond .val "^#{val}$"
        fill-query val
        return false
    return if window.grok-hash!
    if isCordova
      fill-query MOE-ID
      $ \#query .val ''
    else if location.hash isnt /^#./
      fetch MOE-ID

  window.grok-hash = grok-hash = ->
    return false unless location.hash is /^#./
    try
      val = decodeURIComponent location.hash.substr 1
      lang = \a
      if val.0 is \!
        lang = \t
        val.=substr 1
      if lang isnt LANG
        LANG := LANG
        prevVal = ''
        return window.press-lang lang, val
      return true if val is prevVal
      $ \#query .show!
      fill-query val
      fetch val
      return true if val is prevVal
    return false

  window.fill-query = fill-query = ->
    title = decodeURIComponent(it) - /[（(].*/
    title -= /^!/
    return if title is /^</
    $ \#query .val title
    $ \#cond .val "^#{title}$"
    input = $ \#query .get 0
    if isMobile
      try $(\#query).autocomplete \close
    else
      input.focus!
      try input.select!
    lookup title
    return true

  prevId = prevVal = null
  lenToRegex = {}

  bucket-of = ->
    code = it.charCodeAt(0)
    if 0xD800 <= code <= 0xDBFF
      code = it.charCodeAt(1) - 0xDC00
    return code % 1024

  lookup = ->
    if $(\#query).val!
      $(\.erase).show!
      $(\.lang).hide!
      return do-lookup b2g that
    $(\.lang).show!
    $(\.erase).hide!

  window.do-lookup = do-lookup = (val) ->
    title = val - /[（(].*/
    if isCordova or not Index
      return if title is /object/
      return true if Index and Index.indexOf("\"#title\"") is -1
      id = title
    else
      return true if prevVal is val
      prevVal := val
      return true unless Index.indexOf("\"#title\"") >= 0
      id = title
    return true if prevId is id or (id - /\(.*/) isnt (val - /\(.*/)
    $ \#cond .val "^#{title}$"
    entryHistory.push title
    $(\.back).show! if isCordova
    fetch title
    return true

  htmlCache = {t:[], a:[]}
  fetch = ->
    return unless it
    prevId := it
    prevVal := it
    setPref \prev-id prevId
    hash = "#{ if LANG is \a then \# else \#! }#it"
    try history.pushState null, null, hash unless "#{location.hash}" is hash
    if isMobile
      $('#result div, #result span, #result h1:not(:first)').hide!
      $('#result h1:first').text(it).show!
    else
      $('#result div, #result span, #result h1:not(:first)').css \visibility \hidden
      $('#result h1:first').text(it).css \visibility \visible
      window.scroll-to 0 0
    return if load-cache-html it
    return fill-json MOE if it is \萌
    return load-json it

  load-json = (id, cb) ->
    return $.get("#LANG/#{ encodeURIComponent(id - /\(.*/)}.json", null, (-> fill-json it, id, cb), \text) unless isCordova
    # Cordova
    bucket = bucket-of id
    return fill-bucket id, bucket if bucketCache[LANG][bucket]
    json <- $.get "p#{LANG}ck/#bucket.txt"
    bucketCache[LANG][bucket] = json
    return fill-bucket id, bucket

  set-pinyin-bindings = ->
    $('#result.prefer-pinyin-true .bopomofo .bpmf, #result.prefer-pinyin-false .bopomofo .pinyin').unbind(\click).click ->
      val = !getPref \prefer-pinyin
      setPref \prefer-pinyin val
      $('#result').removeClass "prefer-pinyin-#{!val}" .addClass "prefer-pinyin-#val"
      callLater set-pinyin-bindings

  set-html = (html) -> callLater ->
    $ \#result .html html
    $('#result .part-of-speech a').attr \href, null
    set-pinyin-bindings!

    cache-loading := no
    return if isCordova
    $('#result .trs.pinyin').each(-> $(@).attr \title trs2bpmf $(@).text!).tooltip tooltipClass: \bpmf

    $('#result a[href]').tooltip {
      +disabled, tooltipClass: "prefer-pinyin-#{ !!getPref \prefer-pinyin }", show: 100ms, hide: 100ms, items: \a, content: (cb) ->
        id = $(@).text!
        callLater ->
          if htmlCache[LANG][id]
            cb htmlCache[LANG][id]
            return
          load-json id, -> cb it
        return
    }
    $('#result a[href]').hoverIntent do
        timeout: 250ms
        over: -> try $(@).tooltip \open
        out: -> try $(@).tooltip \close
    <- setTimeout _, 250ms
    $('.ui-tooltip').remove!
    <- setTimeout _, 250ms
    $('.ui-tooltip').remove!

  load-cache-html = ->
    html = htmlCache[LANG][it]
    return false unless html
    set-html html
    return true

  fill-json = (part, id, cb=set-html) ->
    while part is /"`辨~\u20DE&nbsp`似~\u20DE"[^}]*},{"f":"([^（]+)[^"]*"/
      part.=replace /"`辨~\u20DE&nbsp`似~\u20DE"[^}]*},{"f":"([^（]+)[^"]*"/ '"辨\u20DE 似\u20DE $1"'
    part.=replace /"`(.)~\u20DE"[^}]*},{"f":"([^（]+)[^"]*"/g '"$1\u20DE $2"'
    part.=replace /"([hbpdcnftrelsaqTAVCD_])"/g (, k) -> keyMap[k]
    h = "#{ if LANG is \a then \# else \#! }"
    part.=replace /`([^~]+)~/g (, word) -> "<a href='#h#word'>#word</a>"
    if JSON?parse?
      html = render JSON.parse part
    else
      html = eval "render(#part)"
    html.=replace /(.)\u20DE/g          "</span><span class='part-of-speech'>$1</span><span>"
    html.=replace //<a[^<]+>#id<\/a>//g "#id"
    html.=replace //<a>([^<]+)</a>//g   "<a href='#{h}$1'>$1</a>"
    html.=replace //(>[^<]*)#id//g      "$1<b>#id</b>"
    html.=replace(/\uFFF9/g '<span class="ruby"><span class="rb"><span class="ruby"><span class="rb">').replace(/\uFFFA/g '</span><br><span class="rt trs pinyin">').replace(/\uFFFB/g '</span></span></span></span><br><span class="rt mandarin">').replace(/<span class="rt mandarin">\s*<\//g '</')
    cb(htmlCache[LANG][id] = html)
    return

  bucketCache = {t:{}, a:{}}

  keyMap = {
    h: \"heteronyms" b: \"bopomofo" p: \"pinyin" d: \"definitions"
    c: \"stroke_count" n: \"non_radical_stroke_count" f: \"def"
    t: \"title" r: \"radical" e: \"example" l: \"link" s: \"synonyms"
    a: \"antonyms" q: \"quote" _: \"id"

    T: \"trs" A: \"alt" V: \"vernacular", C: \"combined" D: \"dialects"
  }

  fill-bucket = (id, bucket) ->
    raw = bucketCache[LANG][bucket]
    key = escape id
    idx = raw.indexOf('"' + key + '"');
    return if idx is -1
    part = raw.slice(idx + key.length + 3);
    idx = part.indexOf('\n')
    part = part.slice(0, idx)
    fill-json part

  $.get "#LANG/index.json", null, init-autocomplete, \text
  return init!

const MOE = '{"h":[{"b":"ㄇㄥˊ","d":[{"f":"`草木~`初~`生~`的~`芽~。","q":["`說文解字~：「`萌~，`艸~`芽~`也~。」","`唐~．`韓愈~、`劉~`師~`服~、`侯~`喜~、`軒轅~`彌~`明~．`石~`鼎~`聯句~：「`秋~`瓜~`未~`落~`蒂~，`凍~`芋~`強~`抽~`萌~。」"],"type":"`名~"},{"f":"`事物~`發生~`的~`開端~`或~`徵兆~。","q":["`韓非子~．`說~`林~`上~：「`聖人~`見~`微~`以~`知~`萌~，`見~`端~`以~`知~`末~。」","`漢~．`蔡邕~．`對~`詔~`問~`灾~`異~`八~`事~：「`以~`杜漸防萌~，`則~`其~`救~`也~。」"],"type":"`名~"},{"f":"`人民~。","e":["`如~：「`萌黎~」、「`萌隸~」。"],"l":["`通~「`氓~」。"],"type":"`名~"},{"f":"`姓~。`如~`五代~`時~`蜀~`有~`萌~`慮~。","type":"`名~"},{"f":"`發芽~。","e":["`如~：「`萌芽~」。"],"q":["`楚辭~．`王~`逸~．`九思~．`傷~`時~：「`明~`風~`習習~`兮~`龢~`暖~，`百草~`萌~`兮~`華~`榮~。」"],"type":"`動~"},{"f":"`發生~。","e":["`如~：「`故態復萌~」。"],"q":["`管子~．`牧民~：「`惟~`有道~`者~，`能~`備~`患~`於~`未~`形~`也~，`故~`禍~`不~`萌~。」","`三國演義~．`第一~`回~：「`若~`萌~`異心~，`必~`獲~`惡報~。」"],"type":"`動~"}],"p":"méng"}],"n":8,"r":"`艸~","c":12,"t":"萌"}'

function init-autocomplete (text)
  Index := text
  $.widget "ui.autocomplete", $.ui.autocomplete, {
    _close: -> @menu.element.addClass \invisible
    _resizeMenu: ->
      ul = @menu.element;
      ul.outerWidth Math.max(
        ul.width( "" ).outerWidth() + 1
        this.element.outerWidth()
      )
      ul.removeClass \invisible
    _value: ->
      fill-query it if it
      @valueMethod.apply @element, arguments
  }
  $(\#query).autocomplete do
    position:
      my: "left bottom"
      at: "left top"
    select: (e, {item}) ->
      return false if item?value is /^\(/
      fill-query item.value if item?value
      return true
    change: (e, {item}) ->
      return false if item?value is /^\(/
      fill-query item.value if item?value
      return true
    source: ({term}, cb) ->
      return cb [] unless term.length
      return cb [] unless term is /[^\u0000-\u00FF]/
      term.=replace(/\*/g '%')
      regex = term
      if term is /\s$/ or term is /\^/
        regex -= /\^/g
        regex -= /\s*$/g
        regex = '"' + regex
      else
        regex = '[^"]*' + regex unless term is /[?._%]/
      if term is /^\s/ or term is /\$/
        regex -= /\$/g
        regex -= /\s*/g
        regex += '"'
      else
        regex = regex + '[^"]*' unless term is /[?._%]/
      regex -= /\s/g
      if term is /[%?._]/
        regex.=replace(/[?._]/g, '[^"]')
        regex.=replace(/%/g '[^"]*')
        regex = "\"#regex\""
      regex.=replace(/\(\)/g '')
      results = try Index.match(//#{ b2g regex }//g)
      return cb [''] unless results
      do-lookup(results.0 - /"/g) if results.length is 1
      MaxResults = 255 # (if isCordova then 100 else 1000)
      if results.length > MaxResults
        more = "(僅顯示前 #MaxResults 筆)"
        results.=slice(0, MaxResults)
        results.push more
      return cb ((results.join(',') - /"/g) / ',')

const CJK-RADICALS = '⼀一⼁丨⼂丶⼃丿⼄乙⼅亅⼆二⼇亠⼈人⼉儿⼊入⼋八⼌冂⼍冖⼎冫⼏几⼐凵⼑刀⼒力⼓勹⼔匕⼕匚⼖匸⼗十⼘卜⼙卩⼚厂⼛厶⼜又⼝口⼞囗⼟土⼠士⼡夂⼢夊⼣夕⼤大⼥女⼦子⼧宀⼨寸⼩小⼪尢⼫尸⼬屮⼭山⼮巛⼯工⼰己⼱巾⼲干⼳幺⼴广⼵廴⼶廾⼷弋⼸弓⼹彐⼺彡⼻彳⼼心⼽戈⼾戶⼿手⽀支⽁攴⽂文⽃斗⽄斤⽅方⽆无⽇日⽈曰⽉月⽊木⽋欠⽌止⽍歹⽎殳⽏毋⽐比⽑毛⽒氏⽓气⽔水⽕火⽖爪⽗父⽘爻⽙爿⺦丬⽚片⽛牙⽜牛⽝犬⽞玄⽟玉⽠瓜⽡瓦⽢甘⽣生⽤用⽥田⽦疋⽧疒⽨癶⽩白⽪皮⽫皿⽬目⽭矛⽮矢⽯石⽰示⽱禸⽲禾⽳穴⽴立⽵竹⽶米⽷糸⺰纟⽸缶⽹网⽺羊⽻羽⽼老⽽而⽾耒⽿耳⾀聿⾁肉⾂臣⾃自⾄至⾅臼⾆舌⾇舛⾈舟⾉艮⾊色⾋艸⾌虍⾍虫⾎血⾏行⾐衣⾑襾⾒見⻅见⾓角⾔言⻈讠⾕谷⾖豆⾗豕⾘豸⾙貝⻉贝⾚赤⾛走⾜足⾝身⾞車⻋车⾟辛⾠辰⾡辵⻌辶⾢邑⾣酉⾤釆⾥里⾦金⻐钅⾧長⻓长⾨門⻔门⾩阜⾪隶⾫隹⾬雨⾭靑⾮非⾯面⾰革⾱韋⻙韦⾲韭⾳音⾴頁⻚页⾵風⻛风⾶飛⻜飞⾷食⻠饣⾸首⾹香⾺馬⻢马⾻骨⾼高⾽髟⾾鬥⾿鬯⿀鬲⿁鬼⿂魚⻥鱼⻦鸟⿃鳥⿄鹵⻧卤⿅鹿⿆麥⻨麦⿇麻⿈黃⻩黄⿉黍⿊黑⿋黹⿌黽⻪黾⿍鼎⿎鼓⿏鼠⿐鼻⿑齊⻬齐⿒齒⻮齿⿓龍⻰龙⿔龜⻳龟⿕龠'

const SIMP-TRAD = """
与與丒囟专專丗卅业業丛叢东東丝絲両兩丢丟两兩严嚴丧喪个個丬爿丯丰临臨丶⼂为為丽麗举舉义義乌烏乐樂乔喬习習乡鄉书書买買乱亂亀龜亁乾争爭亏虧亘亙亚亞产產亩畝亲親亵褻亸嚲亻人亿億仅僅从從仑崙仓倉仪儀们們仮假众眾会會伛傴伞傘伟偉传傳伤傷伥倀伦倫伧傖伪偽伫佇体體佥僉侠俠侣侶侥僥侦偵侧側侨僑侩儈侪儕侬儂俣俁俦儔俨儼俩倆俪儷俭儉债債倾傾偬傯偻僂偾僨偿償傥儻傧儐储儲傩儺兎兔兑兌兖兗兪俞兰蘭关關兴興兹茲养養兽獸兾糞兿藝冁囅内內円丹冈岡册冊写寫军軍农農冝宜冦寇冧霖冨富冩寫冮江冯馮冲沖决決况況冸泮冺泯冻凍冿津净淨凁涑凂浼凃涂凄淒凉涼减減凑湊凒溰凓溧凕溟凖準凙澤凛凜凟瀆凤鳳凥尻処處凨云凫鳧凬凰凭憑凮鳳凯凱凴憑击擊凼窞凾亟凿鑿刄刃刅刃刋刊刍芻刘劉则則刚剛创創删刪刦劫刧劫别別刭剄刴剁刹剎刼劫刽劊刿劌剀剴剂劑剐剮剑劍剥剝剧劇剰剩劎劍劒劍劔劍劝勸办辦务務劢勱动動励勵劲勁劳勞労勞劵卷効效劽裂势勢勅敕勋勛勐猛勚勩勠戮勥強勧勸匀勻匦匭匮匱区區医醫华華协協单單卖賣単單卙斟卛攣卟嚇卢盧卤鹵卥囟卧臥卫衛却卻卺巹厅廳历歷厉厲压壓厌厭厕廁厛廳厠廁厢廂厣厴厦廈厨廚厩廄厮廝厰廠厳嚴厶⼛县縣叁參叄參叆靉叇靆双雙収收叏發叐發发發变變叙敘叠疊叧另叶葉号號叹嘆叽嘰吓嚇吕呂吖嗄吗嗎吣唚吨噸启啟吴吳吿告呋咐呐吶呑吞呒嘸呓囈呕嘔呖嚦呗唄员員呙咼呛嗆呜嗚呪咒咏詠咙嚨咛嚀咝吱咣光咤吒哌呱响響哐匡哑啞哒噠哓嘵哔嗶哕噦哗嘩哙噲哜嚌哝噥哟喲唝嗊唠嘮唡啢唢嗩唣嗦唤喚唿呼啉咻啧嘖啬嗇啭囀啰囉啴嘽啸嘯喷噴喹奎喽嘍喾嚳嗪唚嗫囁嗬呵嗳噯嗵通嘘噓嘞咧嘠嘎嘣迸嘤嚶嘨嘯嘭膨嘱囑嘷嚎噜嚕噻塞噼劈嚔涕嚢囊嚣囂嚯謔团團园園囱囪围圍囵圇国國图圖圆圓圣聖圹壙场場块塊坚堅坛壇坜壢坝壩坞塢坟墳坠墜垄壟垅壟垆壚垒壘垦墾垧坰垩堊垫墊垲塏垴瑙埘塒埚堝堑塹堕墮塡填塬原墙牆壮壯声聲壳殼壶壺壸壼夂⼢处處备備夊⼢够夠头頭夹夾夺奪奁奩奂奐奋奮奖獎奥奧妆妝妇婦妈媽妩嫵妪嫗妫媯姗姍姹奼娄婁娅婭娆嬈娇嬌娈孌娱娛娲媧娴嫻婳嫿婴嬰婵嬋婶嬸媪媼嫒嬡嫔嬪嫱嬙嬷嬤孙孫学學孪孿孶孳宝寶实實宠寵审審宪憲宫宮宽寬宾賓寝寢对對寻尋导導対對寿壽専專尅剋将將尓爾尔爾尘塵尝嘗尧堯尴尷尽盡层層屃屭屉屜届屆屛屏属屬屡屢屦屨屿嶼岁歲岂豈岖嶇岗崗岘峴岙嶴岚嵐岛島岭嶺岿巋峄嶧峡峽峣嶢峤嶠峥崢峦巒峯峰崂嶗崃崍崄嶮崭嶄崾要嵘嶸嵚嶔嵝嶁巄巃巅巔巌巖巓巔巩鞏币幣帅帥师師帏幃帐帳帜幟带帶帧幀帮幫帯帶帱幬帻幘帼幗幂冪幇幫幚幫幞襆幷并广廣庁廳広麼庄莊庅麼庆慶庐廬庑廡库庫应應庙廟庞龐废廢庼廎廏廄廐廄廪廩廴⼵廵巡开開异異弃棄弑弒张張弥彌弯彎弹彈强強归歸当當录錄彚彙彛羿彜羿彟獲彠獲彡⼺彦彥彻徹径徑徕徠徸德忄心忆憶忏懺忧憂忾愾怀懷态態怂慫怃憮怅悵怆愴怜憐总總怼懟怿懌恋戀恒恆恳懇恶惡恸慟恹懨恺愷恻惻恼惱恽惲悦悅悫愨悬懸悭慳悯憫惊驚惧懼惨慘惩懲惫憊惬愜惭慚惮憚惯慣惽惛愠慍愤憤愦憒慑懾慭憖憷楚懑懣懒懶懔懍懴懺戅戇戆戇戋戔戏戲戗戧战戰戝敗戦戰戬戩戯戲戱戲户戶戸戶扌手执執扩擴扪捫扫掃扬揚扰擾抅拘抚撫抛拋抟摶抠摳抡掄抢搶护護报報担擔拟擬拢攏拣揀拥擁拦攔拧擰拨撥择擇挚摯挛攣挜掗挝撾挞撻挟挾挠撓挡擋挢撟挣掙挤擠挥揮挦撏捞撈损損捡撿换換捣搗掳擄掴摑掷擲掸撣掺摻掼摜揸喳揽攬揿撳搀攙搁擱搂摟搃摠搅攪携攜摄攝摅攄摆擺摇搖摈擯摊攤撃擊撄攖撑撐撪攆撵攆撷擷撹攪撺攛擕攜擞擻擡抬擥掔擧舉擪壓攒攢攵又敇敕敌敵敛斂敮歃数數斉齊斋齋斎齋斓斕斩斬断斷旧舊时時旷曠旸暘昙曇昼晝昽曨显顯晋晉晓曉晔曄晕暈晖暉暂暫暧曖术術杀殺杂雜权權条條来來杨楊极極枞樅枢樞枣棗枥櫪枧見枨棖枪槍枫楓枭梟柠檸柽檉栀梔栅柵标標栈棧栉櫛栊櫳栋棟栌櫨栎櫟栏欄树樹样樣栾欒桊棬桠椏桡橈桢楨档檔桤榿桥橋桦樺桧檜桨槳桩樁梦夢梼檮梾棶检檢棂欞椁槨椟櫝椠槧椭橢楼樓楽樂榄欖榇櫬榈櫚榉櫸榘矩槚檟槛檻槟檳槠櫧横橫樯檣樱櫻橥櫫橱櫥橹櫓橼櫞檪櫟檫察欢歡欤歟欧歐歳歲歴曆歺歲歼殲殁歿殇殤残殘殒殞殓殮殚殫殡殯殱殲殴毆毁毀毂轂毕畢毙斃毡氈毵毿毶鞠気氣氢氫氩氬氲氳氵水氽汆汇匯汉漢污汙汤湯汹洶沟溝没沒沣灃沤漚沥瀝沦淪沧滄沨渢沩溈沪滬沵濔泞濘泪淚泶澩泷瀧泸瀘泺濼泻瀉泼潑泽澤泾涇洁潔浃浹浅淺浆漿浇澆浈湞浊濁测測浍澮济濟浏瀏浐滻浑渾浒滸浓濃浔潯浕濜浜濱涙淚涛濤涝澇涞淶涟漣涡渦涣渙涤滌润潤涧澗涨漲涩澀淀澱渊淵渌淥渍漬渎瀆渐漸渑澠渔漁渖瀋渗滲温溫湼涅湾灣湿濕溃潰溅濺溆漵溇漊滙匯滚滾滝瀧滞滯滟灩滠灄满滿滢瀅滤濾滥濫滦灤滨濱滩灘滪澦漑溉潆瀠潇瀟潋瀲潍濰潜潛潴瀦澜瀾濑瀨濒瀕灎灩灏灝灔灩灜瀛灧灩灬火灭滅灯燈灵靈灾災灿燦炀煬炉爐炖燉炜煒炝熗点點炼煉炽熾烁爍烂爛烃烴烛燭烟煙烦煩烧燒烨燁烩燴烫燙烬燼热熱焕煥焖燜焘燾煅煆煳糊煺退熘溜爱愛爲為爷爺牍牘牜牛牦犛牵牽牺犧犊犢犟強犭犬状狀犷獷犸馬犹猶狈狽狍包狝獮狞獰独獨狭狹狮獅狯獪狰猙狱獄狲猻猃獫猎獵猕獼猡玀猪豬猫貓猬蝟献獻獭獺玑璣玙璵玚瑒玛瑪玮瑋环環现現玱瑲玺璽珏玨珐琺珑瓏珰璫珱瓔珲琿琏璉琐瑣琼瓊瑶瑤瑷璦璎瓔瓒瓚瓯甌産產电電画畫畅暢畲畬畳疊畴疇畵畫疎疏疖癤疗療疟瘧疠癘疡瘍疬癆疮瘡疯瘋疴痾痈癰痉痙痖啞痨癆痩瘦痪瘓痫癇痬瘍瘅癉瘆疹瘗瘞瘘瘺瘪癟瘫癱瘾癮瘿癭癀廣癍斑癎癇癞癩癣癬癫癲発發皑皚皱皺皲皸盏盞盐鹽监監盖蓋盗盜盘盤県縣眍區眞真眦眥眬矓着著睁睜睐睞睑瞼瞒瞞瞩矚矤病矫矯矶磯矾礬矿礦砀碭码碼砖磚砗硨砚硯砜風砺礪砻礱砾礫础礎硁硜硕碩硖硤硗磽硙磑硚礄硷鹼碍礙碛磧碜磣碱鹼碹宣磙袞礻示礼禮祎禕祢禰祯禎祷禱祸禍禀稟禄祿禅禪离離秃禿秆稈积積称稱秽穢秾穠税稅稣穌稳穩穑穡穷窮窃竊窍竅窑窯窜竄窝窩窥窺窦竇窭窶竖豎竜龍竞競笃篤笋筍笔筆笕筧笺箋笼籠笾籩筚篳筛篩筜簹筝箏筹籌签簽简簡箓籙箢宛箦簀箧篋箨籜箩籮箪簞箫簫篑簣篓簍篮籃篱籬簖籪籁籟籴糴类類籼秈粜糶粝糲粤粵粪糞粮糧糁糝糇餱糹糸紧緊絵繪絶絕絷縶綘健継繼続續緜綿縂總縄繩繋繫繍繡纟糸纠糾纡紆红紅纣紂纤纖纥紇约約级級纨紈纩纊纪紀纫紉纬緯纭紜纮紘纯純纰紕纱紗纲綱纳納纴紝纵縱纶綸纷紛纸紙纹紋纺紡纻紵纼紖纽紐纾紓线線绀紺绁紲绂紱练練组組绅紳细細织織终終绉縐绊絆绋紼绌絀绍紹绎繹经經绐紿绑綁绒絨结結绔褲绕繞绖絰绗絎绘繪给給绚絢绛絳络絡绝絕绞絞统統绠綆绡綃绢絹绣繡绤綌绥綏绦絛继繼绨綈绩績绪緒绫綾续續绮綺绯緋绰綽绱鞜绲緄绳繩维維绵綿绶綬绷繃绸綢绹綯绺綹绻綣综綜绽綻绾綰绿綠缀綴缁緇缂緙缃緗缄緘缅緬缆纜缇緹缈緲缉緝缊縕缋繢缌緦缍綞缎緞缏緶缐線缑緱缒縋缓緩缔締缕縷编編缗緡缘緣缙縉缚縛缛縟缜縝缝縫缞縗缟縞缠纏缡縭缢縊缣縑缤繽缥縹缦縵缧縲缨纓缩縮缪繆缫繅缬纈缭繚缮繕缯繒缰韁缱繾缲繰缳繯缴繳缵纘罂罌罗羅罚罰罢罷罴羆羁羈羗羌羟羥羡羨羣群羮羹翘翹翙翽翚翬耢勞耥尚耧耬耸聳耻恥聂聶聋聾职職聍聹联聯聩聵聪聰肀聿肃肅肠腸肤膚肷欠肾腎肿腫胀脹胁脅胆膽胧朧胨東胪臚胫脛胶膠脉脈脍膾脏髒脐臍脑腦脓膿脔臠脚腳脱脫脲反脶腡脸臉腭齶腻膩腽膃腾騰膑臏臓摹臜臢舆輿舣艤舰艦舱艙舻艫艰艱艹艸艺藝节節芈羋芗薌芜蕪芦蘆苁蓯苇葦苋莧苌萇苍蒼苎苧苏蘇苘萵茎莖茏蘢茑蔦茔塋茕煢茧繭荆荊荚莢荛蕘荜蓽荞蕎荟薈荠薺荡蕩荣榮荤葷荥滎荦犖荧熒荨蕁荩藎荪蓀荫蔭荬賣荭葒荮紂药藥莅蒞莱萊莲蓮莳蒔莴萵获獲莸蕕莹瑩莺鶯莼蓴菭恰萚蘀萝蘿萤螢营營萦縈萧蕭萨薩葱蔥蒇蕆蒉蕢蒋蔣蒌蔞蓝藍蓟薊蓠蘺蓦驀蔷薔蔹蘞蔺藺蔼藹蕲蘄蕴蘊薮藪藁槁藓蘚蘖蘗虏虜虑慮虚虛虬虯虮蟣虽雖虾蝦虿蠆蚀蝕蚁蟻蚂螞蚕蠶蚬蜆蛊蠱蛎蠣蛏蟶蛮蠻蛰蟄蛱蛺蛲蟯蛳螄蛴蠐蜕蛻蜖汀蜗蝸蝇蠅蝈蟈蝉蟬蝼螻蝾蠑蝿蠅螀螿螨顢蟏蠨蟮蟺蠎蟒衅釁衔銜衤衣补補衬襯衮袞袄襖袅裊袆褘袭襲袯襏袴褲装裝裆襠裈褌裢褳裣襝裤褲裥襉褛褸褴襤襕襴覇霸覚覺覧覽覩睹见見观觀规規觅覓视視觇覘览覽觉覺觊覬觋覡觌覿觎覦觏覯觐覲觑覷觗觝觞觴触觸觯觶訡吟詟讋詤謊誀浴誉譽誊謄説說読讀讁謫讠言计計订訂讣訃认認讥譏讦訐讧訌讨討让讓讪訕讫訖训訓议議讯訊记記讱訒讲講讳諱讴謳讵詎讶訝讷訥许許讹訛论論讼訟讽諷设設访訪诀訣证證诂詁诃訶评評诅詛识識诇詗诈詐诉訴诊診诋詆诌謅词詞诎詘诏詔诐詖译譯诒詒诓誆诔誄试試诖詿诗詩诘詰诙詼诚誠诛誅诜詵话話诞誕诟詬诠詮诡詭询詢诣詣诤諍该該详詳诧詫诨諢诩詡诪譸诫誡诬誣语語诮誚误誤诰誥诱誘诲誨诳誑说說诵誦诶誒请請诸諸诹諏诺諾读讀诼諑诽誹课課诿諉谀諛谁誰谂諗调調谄諂谅諒谆諄谇誶谈談谊誼谋謀谌諶谍諜谎謊谏諫谐諧谑謔谒謁谓謂谔諤谕諭谖諼谗讒谘諮谙諳谚諺谛諦谜謎谝諞谞住谟謨谠讜谡謖谢謝谣謠谤謗谥謚谦謙谧謐谨謹谩謾谪謫谫譾谬謬谭譚谮譖谯譙谰讕谱譜谲譎谳讞谴譴谵譫谶讖豮豶貭亍貮貳賍贓賎賤賖賒賘髒贋贗贘償贝貝贞貞负負贡貢财財责責贤賢败敗账賬货貨质質贩販贪貪贫貧贬貶购購贮貯贯貫贰貳贱賤贲賁贳貰贴貼贵貴贶貺贷貸贸貿费費贺賀贻貽贼賊贽贄贾賈贿賄赀貲赁賃赂賂赃贓资資赅賅赆贐赇賕赈賑赉賚赊賒赋賦赌賭赍齎赎贖赏賞赐賜赑贔赒賙赓賡赔賠赖賴赗賵赘贅赙賻赚賺赛賽赜賾赝贗赞贊赟贇赠贈赡贍赢贏赣贛赪赬赵趙趋趨趱趲趸躉跃躍跄蹌跞躒践踐跶躂跷蹺跸蹕跹躚跻躋踌躊踪蹤踬躓踯躑蹑躡蹒蹣蹰躕蹿躥躏躪躜躦躯軀车車轧軋轨軌轩軒轪軑轫軔转轉轭軛轮輪软軟轰轟轱古轲軻轳轤轴軸轵軹轶軼轷乎轸軫轹轢轺軺轻輕轼軾载載轾輊轿轎辀輈辁輇辂輅较較辄輒辅輔辆輛辇輦辈輩辉輝辊輥辋輞辌輬辍輟辎輜辏輳辐輻辑輯辒轀输輸辔轡辕轅辖轄辗輾辘轆辙轍辚轔辞辭辩辯辫辮辬辨边邊辽遼达達迁遷过過迈邁运運还還这這进進远遠违違连連迟遲迩邇迳逕迹跡选選逊遜递遞逦邐逻邏遗遺遥遙邓鄧邝鄺邬鄔邮郵邹鄒邺鄴邻鄰郄卻郏郟郐鄶郑鄭郓鄆郦酈郧鄖郷鄉郸鄲鄊鄉鄕鄉鄷酆酝醞酦醱酱醬酽釅酾釃酿釀释釋釡斧鉴鑒銮鑾錾鏨鎻鎖钅金钆釓钇釔针針钉釘钊釗钋釙钌釕钍釷钏釧钐釤钑鈒钒釩钓釣钔鍆钕釹钖鍚钗釵钘鈃钙鈣钚鈽钛鈦钜鉅钝鈍钞鈔钟鐘钠鈉钡鋇钢鋼钣鈑钤鈐钥鑰钦欽钧鈞钨鎢钩鉤钪鈧钫鈁钬鈥钮鈕钯鈀钰鈺钱錢钲鉦钳鉗钴鈷钵缽钶鈳钸鈽钹鈸钺鉞钻鑽钼鉬钽鉭钾鉀钿鈿铀鈾铁鐵铂鉑铃鈴铄鑠铅鉛铆鉚铈鈰铉鉉铊鉈铋鉍铌鈮铍鈹铎鐸铏鉶铐銬铑銠铒鉺铓鋩铔錏铕銪铖鋮铗鋏铘邪铙鐃铚銍铛鐺铜銅铝鋁铞吊铟銦铠鎧铡鍘铢銖铣銑铤鋌铥銩铦銛铧鏵铨銓铩鎩铪鉿铫銚铬鉻铭銘铮錚铯銫铰鉸铱銥铲鏟铳銃铴鐋铵銨银銀铷銣铸鑄铹鐒铺鋪铻鋙铼錸铽鋱链鏈铿鏗销銷锁鎖锂鋰锃呈锄鋤锅鍋锆鋯锇鋨锈鏽锉銼锊鋝锋鋒锌鋅锍琉锎鉲锏閒锐銳锑銻锒鋃锓鋟锔鋦锕錒锖錆锗鍺锘若错錯锚錨锛錛锜錡锝鎝锞錁锟錕锠琛锡錫锢錮锣鑼锤錘锥錐锦錦锧鑕锨杴锪忽锫培锬錟锭錠键鍵锯鋸锰錳锱錙锲鍥锴鍇锵鏘锶鍶锷鍔锸鍤锹鍬锺鍾锻鍛锼鎪锽鍠锾鍰锿鑀镀鍍镁鎂镂鏤镃鎡镄鐨镅鋂镆鏌镇鎮镈鎛镉鎘镊鑷镋钂镌鐫镍鎳镎拿镏鎦镐鎬镑鎊镒鎰镓鎵镔鑌镕鎔镖鏢镗鏜镘鏝镙鏍镛鏞镜鏡镝鏑镞鏃镟鏇镠鏐镡鐔镢钁镣鐐镤鏷镥魯镧鑭镨鐠镩串镪鏹镫鐙镬鑊镭鐳镮鐶镯鐲镰鐮镱鐿镲察镳鑣镴鑞镵鑱镶鑲长長閲閱门門闩閂闪閃闫閆闬閈闭閉问問闯闖闰閏闱闈闲閒闳閎间間闵閔闶閌闷悶闸閘闹鬧闺閨闻聞闼闥闽閩闾閭闿闓阀閥阁閣阂閡阃閫阄鬮阅閱阆閬阇闍阈閾阉閹阊閶阋鬩阌閿阍閽阎閻阏閼阐闡阑闌阒闃阓闠阔闊阕闋阖闔阗闐阘闒阙闕阚闞阛闤阝阜队隊阳陽阴陰阵陣阶階际際陆陸陇隴陈陳陉陘陕陝陧隉陨隕险險隂陰隌暗随隨隐隱隠隱隷隸隽雋难難雏雛雠讎雳靂雾霧霁霽霊靈霭靄靓靚静靜靥靨鞑韃鞒轎鞯韉鞲韝鞽轎韦韋韧韌韨韍韩韓韪韙韫韞韬韜韯籤韲齋韵韻顋腮顔顏顕顯页頁顶頂顷頃顸頇项項顺順须須顼頊顽頑顾顧顿頓颀頎颁頒颂頌颃頏预預颅顱领領颇頗颈頸颉頡颊頰颋頲颌頜颍潁颎熲颏頦颐頤频頻颓頹颔頷颕穎颖穎颗顆题題颙顒颚顎颛顓颜顏额額颞顳颟顢颠顛颡顙颢顥颣纇颤顫颥須颦顰颧顴颷飆风風飏颺飐颭飑颮飒颯飓颶飔颸飕颼飖颻飗飀飘飄飙飆飚飆飞飛飨饗飬養飮飲飱餐餍饜饣食饤飣饥飢饦飥饧餳饨飩饩餼饪飪饫飫饬飭饭飯饮飲饯餞饰飾饱飽饲飼饴飴饵餌饶饒饷餉饺餃饼餅饽餑饾餖饿餓馀餘馁餒馂餕馄餛馅餡馆館馇查馈饋馉稹馊餿馋饞馌饁馍饃馎餺馏餾馐饈馑饉馒饅馓饊馔饌馕囊马馬驭馭驮馱驯馴驰馳驱驅驲馹驳駁驴驢驵駔驶駛驷駟驸駙驹駒驺騶驻駐驼駝驽駑驾駕驿驛骀駘骁驍骂罵骃駰骄驕骅驊骆駱骇駭骈駢骊驪骋騁验驗骍騂骎駸骏駿骐騏骑騎骒騍骓騅骕驌骖驂骗騙骘騭骙騤骚騷骛騖骜驁骝騮骞騫骟騸骠驃骡騾骢驄骣驏骤驟骥驥骦驦骧驤髅髏髋髖髌髕鬓鬢魇魘魉魎鱼魚鱿魷鲀魨鲁魯鲂魴鲅鱍鲆平鲇占鲈鱸鲊鮓鲋鮒鲍鮑鲎鱟鲐鮐鲑鮭鲒鮚鲔鮪鲕鮞鲖鮦鲙鱠鲚鱭鲛鮫鲜鮮鲞鯗鲟鱘鲠鯁鲡鱺鲢鰱鲣鰹鲤鯉鲥鰣鲦鰷鲧鯀鲨鯊鲩鯇鲫鯽鲭鯖鲮鯪鲰鯫鲱鯡鲲鯤鲳鯧鲴固鲵鯢鲶鯰鲷鯛鲸鯨鲺虱鲻鯔鲼賁鲽鰈鲿鱨鳀鯷鳃鰓鳄鱷鳅鰍鳆鰒鳇鰉鳊扁鳋蚤鳌鰲鳍鰭鳏鰥鳐鰩鳒鰜鳔鰾鳕鱈鳖鱉鳗鰻鳘鱉鳙庸鳛鰼鳜鱖鳝鱔鳞鱗鳟鱒鳡鰲鳢鱧鳣鱣鸟鳥鸠鳩鸡雞鸢鳶鸣鳴鸤鳲鸥鷗鸦鴉鸧鶬鸨鴇鸩鴆鸪鴣鸬鸕鸭鴨鸮鴞鸯鴦鸰鴒鸱鴟鸲鴝鸳鴛鸵鴕鸶鷥鸷鷙鸹鴰鸺鵂鸼鵃鸽鴿鸾鸞鸿鴻鹁鵓鹂鸝鹃鵑鹄鵠鹅鵝鹆鵒鹇鷳鹈鵜鹉鵡鹊鵲鹋苗鹌鵪鹎鵯鹏鵬鹑鶉鹒鶊鹓鵷鹔鷫鹕鶘鹖鶡鹗鶚鹘鶻鹙鶖鹚鶿鹛眉鹜鶩鹝鷊鹞鷂鹠鶹鹡鶺鹢鷁鹣鶼鹤鶴鹥鷖鹦鸚鹧鷓鹨鷚鹩鷯鹪鷦鹫鷲鹬鷸鹭鷺鹯鸇鹰鷹鹱獲鹲鸏鹳鸛鹾鹺麦麥麸麩麹麴麺麵麽麼黄黃黉黌黒黑黙默黡黶黩黷黪黲黾黽鼋黿鼍鼉鼗鞀鼹鼴齄皻齐齊齑齏齿齒龀齔龁齕龂齗龃齟龄齡龅齙龆齠龇齜龈齦龉齬龊齪龋齲龌齷龙龍龚龔龛龕龟龜
"""

function b2g (str)
  return str if LANG is \t
  rv = ''
  for char in (str / '')
    idx = SIMP-TRAD.index-of(char)
    rv += if idx % 2 then char else SIMP-TRAD[idx + 1]
  return rv

function render-radical (char)
  idx = CJK-RADICALS.index-of(char)
  return char if idx % 2
  return CJK-RADICALS[idx + 1]

function render ({ title, heteronyms, radical, non_radical_stroke_count: nrs-count, stroke_count: s-count})
  char-html = if radical then "<div class='radical'><span class='glyph'>#{
    render-radical(radical - /<\/?a[^>]*>/g)
  }</span><span class='count'><span class='sym'>+</span>#{ nrs-count }</span><span class='count'> = #{ s-count }</span> 畫</div>" else ''
  return ls heteronyms, ({id, bopomofo, pinyin, trs, definitions=[], antonyms, synonyms}) ->
    pinyin ?= trs
    bopomofo ?= trs2bpmf "#pinyin"
    """#char-html
      <h1 class='title'>#{ h title }#{ if isWebKit and id then "<audio src='#{
          "http://twblg.dict.edu.tw/holodict_new/audio/#{
            ((100000 + Number id) - /^1/)
          }.mp3"
      }' controls></audio>" else ''}</h1>#{
        if bopomofo then "<div class='bopomofo'>#{
            if pinyin then "<span class='pinyin'>#{ h pinyin
              .replace(/（.*）/, '')
            }</span>" else ''
          }<span class='bpmf'>#{ h bopomofo
            .replace(/ /g, '\u3000')
            .replace(/([ˇˊˋ])\u3000/g, '$1 ')
          }</span></div>" else ''
      }<div class="entry">
      #{ls groupBy(\type definitions.slice!), (defs) ->
        """<div>
        #{ if defs.0.type then "<span class='part-of-speech'>#{
          defs.0.type
        }</span>" else ''}
        <ol>
        #{ls defs, ({ type, def, quote=[], example=[], link=[], antonyms, synonyms }) ->
          """<li><p class='definition'>
            <span class="def">#{
              (h expand-def def).replace(
                /([：。」])([\u278A-\u2793\u24eb-\u24f4])/g
                '$1</span><span class="def">$2'
              )
            }</span>
            #{ ls example, -> "<span class='example'>#{ h it }</span></span>" }
            #{ ls quote,   -> "<span class='quote'>#{   h it }</span>" }
            #{ ls link,    -> "<span class='link'>#{    h it }</span>" }
            #{ if synonyms then "<span class='synonyms'><span class='part-of-speech'>似</span> #{
              h(synonyms.replace(/,/g '、'))
            }</span>" else '' }
            #{ if antonyms then "<span class='antonyms'><span class='part-of-speech'>反</span> #{
              h(antonyms.replace(/,/g '、'))
            }</span>" else '' }
        </p></li>"""}</ol></div>
      """}
      #{ if synonyms then "<span class='synonyms'><span class='part-of-speech'>似</span> #{
        h(synonyms.replace(/,/g '、'))
      }</span>" else '' }
      #{ if antonyms then "<span class='antonyms'><span class='part-of-speech'>反</span> #{
        h(antonyms.replace(/,/g '、'))
      }</span>" else '' }
      </div>
    """/*
      <div class="xrefs">
          <div class="xref-line">
              <span class='xref'><span class='part-of-speech'>國</span> 測試測試</span>
          </div>
          <div class="xref-line">
              <span class='xref'><span class='part-of-speech'>閩</span> 測試測試 測試</span>
          </div>
      </div>
    */
  function expand-def (def)
    def.replace(
      /^\s*<(\d)>\s*([介代副助動名嘆形連]?)/, (_, num, char) -> "#{
        String.fromCharCode(0x327F + parseInt num)
      }#{ if char then "#char\u20DE" else '' }"
    ).replace(
      /<(\d)>/g (_, num) -> String.fromCharCode(0x327F + parseInt num)
    ).replace(
      /[（(](\d)[)）]/g (_, num) -> String.fromCharCode(0x2789 + parseInt num)
    ).replace(/\(/g, '（').replace(/\)/g, '）')
  function ls (entries=[], cb)
    [cb x for x in entries].join ""
  function h (text='')
    # text.replace(/</g '&lt;').replace(/>/g '&gt;')
    if isCordova then text.replace(/\u030d/g '\u0358') else text
  function groupBy (prop, xs)
    return [xs] if xs.length <= 1
    x = xs.shift!
    x[prop] ?= ''
    pre = [x]
    while xs.length
      y = xs.0
      y[prop] ?= ''
      break unless x[prop] is y[prop]
      pre.push xs.shift!
    return [pre] unless xs.length
    return [pre, ...groupBy(prop, xs)]


const Consonants = { p:\ㄅ b:\ㆠ ph:\ㄆ m:\ㄇ t:\ㄉ th:\ㄊ n:\ㄋ l:\ㄌ k:\ㄍ g:\ㆣ kh:\ㄎ ng:\ㄫ h:\ㄏ tsi:\ㄐ ji:\ㆢ tshi:\ㄑ si:\ㄒ ts:\ㄗ j:\ㆡ tsh:\ㄘ s:\ㄙ }
const Vowels = { a:\ㄚ an: \ㄢ ang: \ㄤ ann:\ㆩ oo:\ㆦ onn:\ㆧ o:\ㄜ e:\ㆤ enn:\ㆥ ai:\ㄞ ainn:\ㆮ au:\ㄠ aunn:\ㆯ am:\ㆰ om:\ㆱ m:\ㆬ ong:\ㆲ ng:\ㆭ i:\ㄧ inn:\ㆪ u:\ㄨ unn:\ㆫ ing:\ㄧㄥ in:\ㄧㄣ un:\ㄨㄣ }
const Tones = { p:\ㆴ t:\ㆵ k:\ㆶ h:\ㆷ p$:"ㆴ\u0358" t$:"ㆵ\u0358" k$:"ㆶ\u0358" h$:"ㆷ\u0358" "\u0300":\˪ "\u0301":\ˋ "\u0302":\ˊ "\u0304":\˫ "\u030d":\$ }
re = -> Object.keys(it).sort(-> &1.length - &0.length).join \|
const C = re Consonants
const V = re Vowels
function trs2bpmf (trs)
  return trs if LANG is \a
  trs.replace(/[A-Za-z\u0300-\u030d]+/g ->
    tone = ''
    it.=toLowerCase!
    it.=replace //([\u0300-\u0302\u0304\u030d])// -> tone := Tones[it]; ''
    it.=replace //^(tsh?|[sj])i// '$1ii'
    it.=replace //^(#C)((?:#V)+[ptkh]?)$// -> Consonants[&1] + &2
    it.=replace //[ptkh]$// -> tone := Tones[it+tone]; ''
    it.=replace //(#V)//g -> Vowels[it]
    it + (tone || '\uFFFD')
  ).replace(/[- ]/g '').replace(/\uFFFD/g ' ').replace(/\. ?/g \。).replace(/\? ?/g \？).replace(/\! ?/g \！).replace(/\, ?/g \，)

