(() => {
  "use strict";

  const BTN_ID = "pdd-mobile-toggle";
  const ORDER_BTN_ID = "pdd-mobile-orders";
  const BACKDROP_ID = "pdd-mobile-backdrop";
  const FAV_TAB_ID = "pdd-mobile-fav-tab";
  const FAV_BOX_ID = "pdd-fav-box";
  const STATUS_ID = "pdd-mobile-status";
  const KB_VAR = "--pdd-kb";

  let userToggled = false;

  // ---------- 键盘：visualViewport 高度差注入 --pdd-kb ----------
  const applyKb = () => {
    const vv = window.visualViewport;
    if (!vv) return;
    const kb = Math.max(0, window.innerHeight - vv.height - vv.offsetTop);
    document.documentElement.style.setProperty(KB_VAR, `${Math.round(kb)}px`);
    document.body.classList.toggle("pdd-kb-open", kb > 80);
  };
  if (window.visualViewport) {
    window.visualViewport.addEventListener("resize", applyKb);
    window.visualViewport.addEventListener("scroll", applyKb);
    applyKb();
  }

  // ---------- 抽屉 / 订单 ----------
  const setDrawer = (open) => {
    document.body.classList.toggle("pdd-mobile-drawer", open);
    const button = document.getElementById(BTN_ID);
    if (button) button.textContent = open ? "关闭" : "会话";
  };

  const setOrders = (open) => {
    document.body.classList.toggle("pdd-mobile-orders", open);
    const button = document.getElementById(ORDER_BTN_ID);
    if (button) button.textContent = open ? "关闭" : "订单";
  };

  // ---------- 三个页签 ----------
  const setSel = (el, on) => {
    if (!el) return;
    el.classList.toggle("sel", on);
    el.classList.toggle("active", on);
  };

  const showFavView = (on, which) => {
    document.body.classList.toggle("pdd-fav-view", on);
    if (on) renderOfficialFav();
    const today = document.querySelector(".left-panel .conv-today");
    const recent = document.querySelector(".left-panel .conv-recent");
    const favTab = document.getElementById(FAV_TAB_ID);
    setSel(favTab, on);
    if (on) {
      setSel(today, false);
      setSel(recent, false);
    } else if (which === "today") {
      setSel(today, true);
      setSel(recent, false);
    } else if (which === "recent") {
      setSel(recent, true);
      setSel(today, false);
    }
  };

  const syncTabState = () => {
    const today = document.querySelector(".left-panel .conv-today");
    const recent = document.querySelector(".left-panel .conv-recent");
    const favTab = document.getElementById(FAV_TAB_ID);
    if (!today && !recent) return;
    const on = document.body.classList.contains("pdd-fav-view");
    if (on) {
      setSel(favTab, true);
      setSel(today, false);
      setSel(recent, false);
      return;
    }
    setSel(favTab, false);
    const todayOn = today && (today.classList.contains("sel") || today.classList.contains("active"));
    const recentOn = recent && (recent.classList.contains("sel") || recent.classList.contains("active"));
    if (!todayOn && !recentOn) setSel(today, true);
  };

  // ---------- 官方“收藏会话”分组：克隆到收藏视图 ----------
  const findFavGroupBlock = () => {
    const list = document.querySelector(".left-panel .chat-list-box");
    if (!list) return null;
    const nodes = Array.from(list.querySelectorAll("div,section,ul"));
    const candidates = nodes.filter((el) => {
      if (el === list) return false;
      const text = (el.textContent || "").replace(/\s+/g, "");
      if (!text.includes("收藏会话")) return false;
      return !!el.querySelector(".chat-item");
    });
    if (!candidates.length) return null;
    candidates.sort((a, b) =>
      a.querySelectorAll(".chat-item").length - b.querySelectorAll(".chat-item").length);
    return candidates[0];
  };

  const ensureFavBox = () => {
    let box = document.getElementById(FAV_BOX_ID);
    if (box) return box;
    const wrapper = document.querySelector(".left-panel .conv-tab-wrapper");
    if (!wrapper) return null;
    box = document.createElement("div");
    box.id = FAV_BOX_ID;
    wrapper.insertAdjacentElement("afterend", box);
    return box;
  };

  // 从官方收藏分组里提取会话信息，重建成与普通列表一致的紧凑行
  const extractFavRows = (group) => {
    const imgs = Array.from(group.querySelectorAll("img"));
    const rows = [];
    const used = new Set();
    imgs.forEach((img) => {
      let item = img;
      for (let i = 0; i < 7 && item; i += 1) {
        const cls = typeof item.className === "string" ? item.className : "";
        if (/chat-item|conversation|chat-card|fav-item|item-card/i.test(cls)) break;
        item = item.parentElement;
      }
      const source = item || img.parentElement;
      if (!source || used.has(source)) return;
      used.add(source);
      const leaves = Array.from(source.querySelectorAll("*"))
        .filter((el) => el.children.length === 0)
        .map((el) => (el.textContent || "").trim())
        .filter(Boolean);
      const time = leaves.find((t) => /^\d{1,2}:\d{2}$/.test(t) || /昨天|前天|刚刚/.test(t)) || "";
      const name = leaves.find((t) => t.includes("*") && t.length <= 18) || leaves[0] || "";
      const rest = leaves.filter((t) => t !== name && t !== time);
      const tagPattern = /购买力|老客|新客|粉丝|等级|^\d+级$/;
      const msg = rest.find((t) => !tagPattern.test(t) && t.length > 1) || rest[0] || "";
      rows.push({ img: img.src || "", name, msg, time, source });
    });
    return rows;
  };

  const renderOfficialFav = () => {
    const box = ensureFavBox();
    if (!box) return;
    box.innerHTML = "";
    const group = findFavGroupBlock();
    if (!group) {
      const empty = document.createElement("div");
      empty.className = "pdd-fav-empty";
      empty.textContent = "暂无收藏会话";
      box.appendChild(empty);
      return;
    }
    const rows = extractFavRows(group);
    if (!rows.length) {
      const empty = document.createElement("div");
      empty.className = "pdd-fav-empty";
      empty.textContent = "暂无收藏会话";
      box.appendChild(empty);
      return;
    }
    rows.forEach((row) => {
      const item = document.createElement("div");
      item.className = "pdd-fav-row";

      const avatar = document.createElement("img");
      avatar.className = "pdd-fav-avatar";
      avatar.src = row.img;
      avatar.alt = "";
      item.appendChild(avatar);

      const main = document.createElement("div");
      main.className = "pdd-fav-main";
      const name = document.createElement("div");
      name.className = "pdd-fav-name";
      name.textContent = row.name;
      const msg = document.createElement("div");
      msg.className = "pdd-fav-msg";
      msg.textContent = row.msg;
      main.appendChild(name);
      main.appendChild(msg);
      item.appendChild(main);

      const time = document.createElement("div");
      time.className = "pdd-fav-time";
      time.textContent = row.time;
      item.appendChild(time);

      item.addEventListener("click", (event) => {
        event.preventDefault();
        event.stopPropagation();
        if (row.source) row.source.click();
        setDrawer(false);
      }, true);
      box.appendChild(item);
    });
  };

  // ---------- 在线/忙碌/离线 ----------
  const stateFromClass = (el) => {
    const cls = el.className || "";
    if (/(^|\s)online(\s|$)/.test(cls)) return "online";
    if (/(^|\s)busy(\s|$)/.test(cls)) return "busy";
    return "offline";
  };
  const stateLabel = { online: "在线", busy: "忙碌", offline: "离线" };

  const bindStatus = () => {
    const header = document.querySelector(".left-panel .header.panel-tab-header");
    if (!header) return;
    const statusEl = header.querySelector(".status");
    if (!statusEl) return;
    let button = document.getElementById(STATUS_ID);
    if (!button) {
      button = document.createElement("button");
      button.id = STATUS_ID;
      button.type = "button";
      button.addEventListener("click", (event) => {
        event.stopPropagation();
        const current = stateFromClass(statusEl);
        const order = ["online", "busy", "offline"];
        const next = order[(order.indexOf(current) + 1) % order.length];
        const targetLabel = stateLabel[next];
        const items = statusEl.querySelectorAll(".status-box li, .sel-box li, ul li");
        let clicked = false;
        items.forEach((item) => {
          const text = (item.textContent || "").trim();
          if (!clicked && text.includes(targetLabel)) {
            item.click();
            clicked = true;
          }
        });
        if (!clicked) statusEl.click();
        window.setTimeout(bindStatus, 400);
      });
      header.appendChild(button);
    }
    const state = stateFromClass(statusEl);
    button.textContent = stateLabel[state];
    button.dataset.state = state;
  };

  // ---------- 隐藏新手引导遮罩（只隐藏元素本身） ----------
  const killGuides = () => {
    const KEY = /(guide-mask|guideMask|guide-mask-wrap|novice-guide|newbie-guide|spotlight|driver-popover|introjs|coach-mark|onboarding-mask|guide-popup)/i;
    document.querySelectorAll("[class],[id]").forEach((el) => {
      if (el.dataset.pddGuideKilled) return;
      const cls = typeof el.className === "string" ? el.className : "";
      const id = el.id || "";
      if (!KEY.test(cls + " " + id)) return;
      const style = getComputedStyle(el);
      if (style.position !== "fixed" && style.position !== "absolute") return;
      el.style.setProperty("display", "none", "important");
      el.dataset.pddGuideKilled = "1";
    });
  };

  // ---------- 待复核黄底统一浅黄、铺满 ----------
  const toneChatItems = () => {
    document.querySelectorAll(".left-panel .chat-item").forEach((li) => {
      const bg = getComputedStyle(li).backgroundColor || "";
      const match = bg.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)/);
      if (match) {
        const r = parseInt(match[1], 10);
        const g = parseInt(match[2], 10);
        const b = parseInt(match[3], 10);
        if (r > 238 && g > 205 && b < 225 && (r - b) > 16) {
          li.style.setProperty("background-color", "#fffaf2", "important");
        }
      }
      li.style.setProperty("margin", "0", "important");
      li.style.setProperty("border-radius", "0", "important");
    });
  };

  // ---------- UI 构建 ----------
  const bindTabs = () => {
    const today = document.querySelector(".left-panel .conv-today");
    const recent = document.querySelector(".left-panel .conv-recent");
    if (!today || !recent) return;
    const tabRow = today.parentElement;
    if (tabRow && !document.getElementById(FAV_TAB_ID)) {
      const favTab = document.createElement("button");
      favTab.id = FAV_TAB_ID;
      favTab.type = "button";
      favTab.textContent = "收藏会话";
      favTab.addEventListener("click", (event) => {
        event.stopPropagation();
        showFavView(true);
      });
      tabRow.appendChild(favTab);
    }
    if (!today.dataset.pddBound) {
      today.dataset.pddBound = "1";
      today.addEventListener("click", () => showFavView(false, "today"));
      recent.addEventListener("click", () => showFavView(false, "recent"));
    }
  };

  const ensureUi = () => {
    if (!document.body) return;

    if (!document.getElementById(BACKDROP_ID)) {
      const backdrop = document.createElement("div");
      backdrop.id = BACKDROP_ID;
      backdrop.addEventListener("click", () => setDrawer(false));
      document.body.appendChild(backdrop);
    }

    if (!document.getElementById(BTN_ID)) {
      const button = document.createElement("button");
      button.id = BTN_ID;
      button.type = "button";
      button.textContent = "会话";
      button.setAttribute("aria-label", "打开或关闭会话列表");
      button.addEventListener("click", () => {
        userToggled = true;
        setDrawer(!document.body.classList.contains("pdd-mobile-drawer"));
      });
      document.body.appendChild(button);
    }

    if (!document.getElementById(ORDER_BTN_ID)) {
      const orderButton = document.createElement("button");
      orderButton.id = ORDER_BTN_ID;
      orderButton.type = "button";
      orderButton.textContent = "订单";
      orderButton.setAttribute("aria-label", "打开或关闭订单栏");
      orderButton.addEventListener("click", () => {
        setOrders(!document.body.classList.contains("pdd-mobile-orders"));
      });
      document.body.appendChild(orderButton);
    }

    bindTabs();
    bindStatus();
  };

  // ---------- 原生返回键通过 hash 控制列表 ----------
  const handleListHash = () => {
    const hash = location.hash || "";
    if (hash === "#pdd-open-list") {
      setDrawer(true);
      try {
        history.replaceState(null, "", location.pathname + location.search);
      } catch (e) { /* 忽略 */ }
    } else if (hash === "#pdd-close-list") {
      setDrawer(false);
      try {
        history.replaceState(null, "", location.pathname + location.search);
      } catch (e) { /* 忽略 */ }
    }
  };
  window.addEventListener("hashchange", handleListHash);

  // ---------- 启动 ----------
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", ensureUi, { once: true });
  } else {
    ensureUi();
  }
  window.setTimeout(ensureUi, 1500);
  window.setTimeout(ensureUi, 4000);
  window.setTimeout(handleListHash, 900);
  window.setInterval(bindStatus, 3000);
  window.setInterval(syncTabState, 1200);
  window.setInterval(killGuides, 1200);
  window.setInterval(toneChatItems, 1500);

  // 点会话后自动回到聊天
  document.addEventListener("click", (event) => {
    const target = event.target;
    if (!target || !target.closest) return;
    const item = target.closest("li.chat-item, .chat-list-box .chat-item");
    if (item) {
      window.setTimeout(() => {
        userToggled = false;
        setOrders(false);
        setDrawer(false);
      }, 300);
    }
  }, true);
})();
