/* Join approval mocks (issue #393). Texts are PROPOSALS, not strings.csv rows. ?screen=tv|settings|waiting|refused|timeout&lang=en|he&queue=2&secs=45 */
(function () {
  var q = new URLSearchParams(location.search);
  var screen = q.get("screen") || document.documentElement.dataset.screen || "tv";
  var lang = q.get("lang") || "en";
  var he = lang === "he";
  var T = {
    en: {
      title: "NEW PLAYER", wants: "WANTS TO JOIN", allow: "ALLOW", refuse: "REFUSE", queue: "+2 WAITING", left: "45 S",
      settings: "SETTINGS", approve: "APPROVE NEW PLAYERS", debug: "DEBUG OVERLAY", invert: "INVERT AXES", music: "MUSIC", effects: "EFFECTS",
      language: "LANGUAGE", langname: "ENGLISH", on: "ON", off: "OFF", back: "BACK", select: "SELECT GAME", room: "ROOM CODE",
      wait: "WAITING FOR THE TV TO LET YOU IN", waitSub: "THE HOST PRESSES OK ON THE TV REMOTE.", cancel: "CANCEL",
      no: "THE TV SAID NO.", noSub: "THE HOST DID NOT LET YOU IN. ASK THE HOST, THEN TRY AGAIN.", again: "TRY AGAIN",
      to: "NO ANSWER FROM THE TV.", toSub: "NOBODY PRESSED OK IN TIME. TRY AGAIN.",
      type: "TYPE THE ROOM CODE FROM THE TV", you: "YOU ARE MAYA", name: "MAYA"
    },
    he: {
      title: "שחקן חדש", wants: "רוצה להצטרף", allow: "לאשר", refuse: "לסרב", queue: "עוד 2 ממתינים", left: "45 שנ׳",
      settings: "הגדרות", approve: "אישור שחקנים חדשים", debug: "מסך אבחון", invert: "היפוך צירים", music: "מוזיקה", effects: "אפקטים",
      language: "שפה", langname: "עברית", on: "פועל", off: "כבוי", back: "חזרה", select: "בחרו משחק", room: "קוד חדר",
      wait: "ממתינים שהטלוויזיה תכניס אתכם", waitSub: "המארח לוחץ אישור בשלט הטלוויזיה.", cancel: "ביטול",
      no: "הטלוויזיה אמרה לא.", noSub: "המארח לא אישר את הכניסה. שאלו את המארח ונסו שוב.", again: "נסו שוב",
      to: "אין תשובה מהטלוויזיה.", toSub: "אף אחד לא לחץ אישור בזמן. נסו שוב.",
      type: "הקלידו את קוד החדר מהטלוויזיה", you: "אתם מייה", name: "מאיה"
    }
  }[lang];
  var root = document.getElementById("root");
  var phone = /waiting|refused|timeout/.test(screen);
  document.documentElement.dir = he ? "rtl" : "ltr";
  document.documentElement.lang = lang;
  document.body.className = phone ? "phone" : "tv";

  function el(tag, cls, html, st) { var e = document.createElement(tag); if (cls) e.className = cls; if (html != null) e.innerHTML = html; if (st) e.style.cssText = st; return e; }
  /* pixel art from rows of characters: "#" = lit, any other = empty */
  function art(rows, px, color) {
    var w = rows[0].length, h = rows.length, s = '<svg xmlns="http://www.w3.org/2000/svg" width="' + w * px + '" height="' + h * px + '" shape-rendering="crispEdges" style="display:block">';
    rows.forEach(function (r, y) { for (var x = 0; x < w; x++) if (r[x] === "#") s += '<rect x="' + x * px + '" y="' + y * px + '" width="' + px + '" height="' + px + '" fill="' + color + '"/>'; });
    return s + "</svg>";
  }
  var X = ["#.....#", "##...##", ".##.##.", "..###..", ".##.##.", "##...##", "#.....#"];
  var CLOCK = ["..#####..", ".#.....#.", "#...#...#", "#...#...#", "#...###.#", "#.......#", ".#.....#.", "..#####.."];
  function key(label, cls) { return '<span class="key ' + (cls || "") + '">' + label + "</span>"; }
  function avatar(px) { return '<i class="avatar" style="width:' + 16 * px + 'px;height:' + 16 * px + 'px;background-size:' + 64 * px + "px " + 128 * px + "px;background-position:-" + 16 * px + "px 0\"></i>"; }

  function backdropGames() {
    var b = el("div", "bd");
    b.innerHTML = '<div class="bd-h"><span class="rp-title" style="font-size:64px">' + T.select + '</span><span style="color:var(--text-dim)">' + T.room + ' <b style="color:var(--accent);font-weight:400">KXQM</b></span></div><div class="bd-t"><i></i><i></i><i></i></div>';
    return b;
  }

  if (screen === "tv") {
    root.appendChild(backdropGames());
    var dim = el("div", "dim");
    var card = el("div", "rp-panel card");
    card.innerHTML =
      '<div class="top"><h2>' + T.title + '</h2><span class="queue">' + T.queue + '</span></div>' +
      '<div class="who">' + avatar(8) + '<div><div class="pname">' + T.name + '</div><div class="wants">' + T.wants + '</div></div></div>' +
      '<div class="timer"><span class="bar">' + new Array(12).join("<i class=on></i>") + '<i></i></span><span class="secs">' + T.left + '</span></div>' +
      '<div class="hints"><span>' + key("OK", "okk") + ' <b class="okl">' + T.allow + '</b></span><span>' + key("BACK", "bkk") + ' <b class="bdl">' + T.refuse + '</b></span></div>';
    dim.appendChild(card); root.appendChild(dim);
  } else if (screen === "settings") {
    var box = el("div", "set");
    box.appendChild(el("h1", "rp-title", T.settings));
    function row(name, val, foc, lo, hi, vc) {
      var r = el("div", "row" + (foc ? " focus" : ""));
      r.innerHTML = '<span class="nm">' + name + '</span><span class="ar' + (lo ? " end" : "") + '">&lt;</span><span class="vl" style="' + (vc ? "color:" + vc : "") + '">' + val + '</span><span class="ar' + (hi ? " end" : "") + '">&gt;</span>';
      return r;
    }
    var rows = el("div", "rows");
    rows.appendChild(row(T.debug, T.off, 0, 1, 0, "var(--text-dim)"));
    rows.appendChild(row(T.invert, T.off, 0, 1, 0, "var(--text-dim)"));
    rows.appendChild(row(T.approve, T.on, 1, 0, 1, "var(--ok)"));
    rows.appendChild(row(T.music, "7 / 10", 0, 0, 0));
    rows.appendChild(row(T.effects, "8 / 10", 0, 0, 0));
    rows.appendChild(row(T.language, T.langname, 0, 0, 0, "var(--accent)"));
    box.appendChild(rows);
    box.appendChild(el("div", "rp-item back", T.back));
    root.appendChild(box);
  } else {
    var p = el("div", "ph");
    var top = el("div", "ptop"); top.innerHTML = '<span class="sq"></span><span class="sq"></span>'; p.appendChild(top);
    var mid = el("div", "pmid");
    if (screen === "waiting") {
      mid.innerHTML = '<div class="dots"><i class="on"></i><i></i><i></i><i></i></div><div class="msg">' + T.wait + '</div><div class="sub">' + T.waitSub + '</div>';
    } else if (screen === "refused") {
      mid.innerHTML = '<div class="ico">' + art(X, 16, "#f83800") + '</div><div class="msg">' + T.no + '</div><div class="sub">' + T.noSub + '</div>';
    } else {
      mid.innerHTML = '<div class="ico">' + art(CLOCK, 14, "#f8b800") + '</div><div class="msg">' + T.to + '</div><div class="sub">' + T.toSub + '</div>';
    }
    p.appendChild(mid);
    var who = el("div", "pwho"); who.innerHTML = '<span class="sqp"></span>' + avatar(5) + '<span class="pn">' + T.name + '</span>';
    p.appendChild(who);
    p.appendChild(el("div", "pbtn", screen === "waiting" ? T.cancel : T.again));
    root.appendChild(p);
  }
})();
