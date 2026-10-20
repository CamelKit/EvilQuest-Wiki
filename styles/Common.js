/* Any JavaScript here will be loaded for all users on every page load. */

// Dynamic Tab Engine Hook for NPC Interfaces
$(document).ready(function() {
    $('.npc-tab-buttons').on('click', '.npc-tab-button', function() {
        var $button = $(this);
        var tabId = $button.data('tab');
        var $container = $button.closest('.npc-tab-container');
        
        // Toggle Active Buttons
        $container.find('.npc-tab-button').removeClass('active');
        $button.addClass('active');
        
        // Toggle Active Infobox Containers
        $container.find('.npc-tab-content').removeClass('active');
        $container.find('.npc-tab-content[data-tab="' + tabId + '"]').addClass('active');
    });
});


/* =================== */
/* ====ITEM DESC====== */
/* =================== */
mw.hook('wikipage.content').add(function() {

    // Remove empty paragraphs
    document.querySelectorAll('.mw-parser-output p').forEach(function(p) {
        if (p.innerHTML.trim() === '' || p.innerHTML.trim() === '<br>') {
            p.style.display = 'none';
        }
    });

    var jsonUrl = '/index.php?title=Module:ItemData/json&action=raw';
    
    fetch(jsonUrl)
        .then(function(r) { return r.json(); })
        .then(function(items) {
            var lookup = {};
            items.forEach(function(item) {
                lookup[item.name] = item.id;
            });

            var links = Array.from(document.querySelectorAll('#mw-content-text a'));
            var toProcess = links.filter(function(link) {
                var title = link.getAttribute('title');
                return title && lookup[title] !== undefined;
            });

            toProcess.forEach(function(link) {
                var title = link.getAttribute('title');
                var id = lookup[title];
                var filename = 'Item_' + id + '.png';

                fetch('/api.php?action=query&titles=File:' + encodeURIComponent(filename) + '&prop=imageinfo&iiprop=url&format=json')
                    .then(function(r) { return r.json(); })
                    .then(function(data) {
                        var pages = data.query.pages;
                        var page = Object.values(pages)[0];
                        if (page.imageinfo && page.imageinfo[0]) {
                            var img = document.createElement('img');
                            img.src = page.imageinfo[0].url;
                            img.style.cssText = 'width:20px; height:20px; object-fit:contain; vertical-align:middle; margin-right:4px;';
                            link.insertBefore(img, link.firstChild);
                        }
                    });
            });
        });
});




/* =================== */
/* =====BIS CALC====== */
/* =================== */

(function() {
  if (!document.getElementById('eq-bis-root')) return;

  var XP_TABLE = [
    0,83,174,276,388,512,650,801,969,1154,1358,1584,1833,2107,2411,2746,3115,
    3523,3973,4470,5018,5624,6291,7028,7842,8740,9730,10824,12031,13363,14833,
    16456,18247,20224,22406,24815,27473,30408,33648,37224,41171,45529,50339,
    55649,61512,67983,75127,83014,91721,101333,111945,123660,136594,150872,
    166636,184040,203254,224466,247886,273742,302288,333804,368599,407015,
    449428,496254,547953,605032,668051,737627,814445,899257,992895,1096278,
    1210421,1336443,1475581,1629200,1798808,1986068,2192818,2421087,2673114,
    2951373,3258594,3597792,3972294,4385776,4842295,5346332,5902831,6517253,
    7195629,7944614,8771558,9684577,10692629,11805606,13034431,14391160,
    15889109,17542976,19368992,21385073,23611006,26068632,28782069,31777943,
    35085654,38737661,42769801,47221641,52136869,57563718,63555443,70170840,
    77474828,85539082,94442737,104273167,115126838,127110260,140341028,
    154948977,171077457,188884740,208545572,230252886,254219702,280681209,
    309897078,342154009,377768545,417090179,460504778,508438379,561361362,
    619793069,684306901,755535943,834179178,921008346,1016875516,1122721449,
    1239584831,1368612462,1511070513,1668356950,1842015252,2147483647
  ];

  var SLOTS = ['head','cape','neck','ammo','weapon','body','shield','legs','hands','ring','feet'];
  var SLOT_LABELS = {head:'Head',cape:'Cape',neck:'Neck',ammo:'Ammo',weapon:'Weapon',body:'Body',shield:'Off-hand',legs:'Legs',hands:'Hands',ring:'Ring',feet:'Feet'};
  var SKILLS = ['Weaponry','Defence','Ranging','Evil Magic','Good Magic'];
  var STAT_KEYS = ['stabAttack','slashAttack','crushAttack','rangedAccuracy','magicAccuracy','stabDefence','slashDefence','crushDefence','rangedDefence','magicDefence','meleeStrength','rangedStrength'];
  var STAT_LABELS = {stabAttack:'Stab Atk',slashAttack:'Slash Atk',crushAttack:'Crush Atk',rangedAccuracy:'Ranged Acc',magicAccuracy:'Magic Acc',stabDefence:'Stab Def',slashDefence:'Slash Def',crushDefence:'Crush Def',rangedDefence:'Ranged Def',magicDefence:'Magic Def',meleeStrength:'Melee Str',rangedStrength:'Ranged Str'};
  var STYLES = ['Melee','Ranged','Magic'];
  var SUBSTATS = {Melee:['Auto','Stab','Slash','Crush'],Ranged:['Auto','Accuracy','Strength'],Magic:['Auto']};
  var STYLE_SKILLS = {Melee:['Weaponry','Defence'],Ranged:['Ranging'],Magic:['Evil Magic','Good Magic']};
  var STYLE_EQUIP_SKILLS = {
    Melee: ['weaponry','defence'],
    Ranged: ['ranging','ranged'],
    Magic: ['evil magic','good magic']
  };
  var EXCLUDED_NPCS = ['shopkeeper','weapon smith','armorer','leg armorer','shield smith','banker'];

  var DESIGN_WIDTH = 1100;

  var BG='#161414', SURFACE='#1c1b1b', BORDER='#a3a9b1', BORDER_DIM='#2b1211', RED_LIGHT='#5c1a14', TEXT='#e6e6e6', TEXT_DIM='#a3a9b1', GREEN='#4caf50';

  function levelToXp(l) { return l>=1&&l<=XP_TABLE.length ? XP_TABLE[l-1] : 0; }

  function calcCombatLevel(skills) {
    var weaponry = skills['Weaponry'] || 1;
    var defence = skills['Defence'] || 1;
    var ranging = skills['Ranging'] || 1;
    var goodmagic = skills['Good Magic'] || 1;
    var evilmagic = skills['Evil Magic'] || 1;
    var t = 0.25 * (defence + weaponry);
    var e = 0.325 * (weaponry + defence);
    var i = 0.325 * (Math.floor(ranging / 2) + ranging);
    var s = Math.max(goodmagic, evilmagic);
    var n = 0.325 * (Math.floor(s / 2) + s);
    return Math.floor(t + Math.max(e, i, n));
  }

  var state = {
    items: [], npcs: [], loading: true, loadingNpcs: true,
    skills: {Weaponry:1,Defence:1,Ranging:1,'Evil Magic':1,'Good Magic':1},
    style: 'Melee', subStat: 'Auto', mode: 'Current', range: 10,
    excluded: {}, locked: {}, lockedItems: {},
    selectedMob: null, mobSearch: '', itemSearch: '',
    iconCache: {},
    no2h: true, noHQ: true,
    menuOpenSlot: null
  };

  function onDocClick() {
    if (state.menuOpenSlot !== null) {
      state.menuOpenSlot = null;
      render();
    }
  }
  document.addEventListener('click', onDocClick);

  function itemMatchesStyle(item, style) {
    if (!item.equipSkill) return true;
    var allowed = STYLE_EQUIP_SKILLS[style] || [];
    var sk = (item.equipSkill || '').toLowerCase();
    return allowed.indexOf(sk) >= 0;
  }

  function hasAnyStats(item) {
    for (var i=0;i<STAT_KEYS.length;i++) { if (item[STAT_KEYS[i]]) return true; }
    return false;
  }

  function isExcluded(item) {
    if (state.excluded[item.name]) return true;
    if (state.no2h && item.twoHanded) return true;
    if (state.noHQ && item.name.indexOf('(HQ)') >= 0) return true;
    return false;
  }

  function getScore(item, style, subStat) {
    if (!item) return 0;
    var s = subStat === 'Auto' ? null : subStat;
    if (style === 'Melee') {
      if (s === 'Stab') return Math.max(item.stabAttack||0, item.stabDefence||0);
      if (s === 'Slash') return Math.max(item.slashAttack||0, item.slashDefence||0);
      if (s === 'Crush') return Math.max(item.crushAttack||0, item.crushDefence||0);
      var atk = Math.max(item.stabAttack||0, item.slashAttack||0, item.crushAttack||0);
      var def = Math.max(item.stabDefence||0, item.slashDefence||0, item.crushDefence||0);
      return Math.max(atk, def);
    }
    if (style === 'Ranged') {
      if (item.equipSlot === 'weapon' || item.equipSlot === 'ammo') {
        if (s === 'Strength') return item.rangedStrength||0;
        return Math.max(item.rangedAccuracy||0, item.rangedDefence||0, item.rangedStrength||0);
      }
      return item.rangedDefence||0;
    }
    if (style === 'Magic') {
      if (item.equipSlot === 'weapon') return Math.max(item.magicAccuracy||0, item.magicDefence||0);
      return item.magicDefence||0;
    }
    return 0;
  }

  function canEquip(item) {
    if (!item.levelRequired || !item.equipSkill) return true;
    var sk = skillKeyToStateKey(item.equipSkill);
    return (state.skills[sk]||1) >= item.levelRequired;
  }

  function skillKeyToStateKey(equipSkill) {
    var lower = (equipSkill||'').toLowerCase();
    if (lower === 'ranged' || lower === 'ranging') return 'Ranging';
    for (var i=0;i<SKILLS.length;i++) { if (SKILLS[i].toLowerCase() === lower) return SKILLS[i]; }
    return equipSkill.charAt(0).toUpperCase() + equipSkill.slice(1);
  }

  var SLOT_REQUIRES_SKILL = {head:true, body:true, legs:true, shield:true, weapon:true};

  function itemMatchesSlotStyle(item, slot, style) {
    if (slot === 'weapon' || slot === 'shield') {
      if (!item.equipSkill) return false;
      var sk = item.equipSkill.toLowerCase();
      if (style === 'Melee') {
        if (slot === 'weapon') return sk === 'weaponry';
        return sk === 'weaponry' || sk === 'defence';
      }
      if (style === 'Ranged') return sk === 'ranged' || sk === 'ranging';
      if (style === 'Magic') return sk === 'evil magic' || sk === 'good magic';
      return false;
    }
    if (SLOT_REQUIRES_SKILL[slot]) {
      if (!item.equipSkill) return false;
      var sk2 = item.equipSkill.toLowerCase();
      if (style === 'Melee') return sk2 === 'defence';
      if (style === 'Ranged') return sk2 === 'ranged' || sk2 === 'ranging';
      if (style === 'Magic') return sk2 === 'evil magic' || sk2 === 'good magic';
      return false;
    }
    return itemMatchesStyle(item, style);
  }

  function getBIS(slot) {
    var best = null, bestScore = -1;
    for (var i=0; i<state.items.length; i++) {
      var it = state.items[i];
      if (!it.equippable || it.equipSlot !== slot || isExcluded(it) || !canEquip(it)) continue;
      if (!itemMatchesSlotStyle(it, slot, state.style)) continue;
      if (!hasAnyStats(it)) continue;
      var sc = getScore(it, state.style, state.subStat);
      if (sc > bestScore) { bestScore = sc; best = it; }
    }
    if (!best) {
      for (var j=0; j<state.items.length; j++) {
        var it2 = state.items[j];
        if (!it2.equippable || it2.equipSlot !== slot || isExcluded(it2) || !canEquip(it2)) continue;
        if (!itemMatchesSlotStyle(it2, slot, state.style)) continue;
        var sc2 = getScore(it2, state.style, state.subStat);
        if (sc2 > bestScore) { bestScore = sc2; best = it2; }
      }
    }
    return best;
  }

  function getNextBIS(slot) {
    var currentBIS = getBIS(slot);
    var currentScore = currentBIS ? getScore(currentBIS, state.style, state.subStat) : -Infinity;
    var maxLevel = 1;
    SKILLS.forEach(function(sk) { if ((state.skills[sk]||1) > maxLevel) maxLevel = state.skills[sk]||1; });
    maxLevel += state.range;
    var best = null;
    for (var i=0; i<state.items.length; i++) {
      var it = state.items[i];
      if (!it.equippable || it.equipSlot !== slot || isExcluded(it)) continue;
      if (!itemMatchesSlotStyle(it, slot, state.style)) continue;
      if (!hasAnyStats(it)) continue;
      if (canEquip(it)) continue;
      if (!it.levelRequired || it.levelRequired > maxLevel) continue;
      if (getScore(it, state.style, state.subStat) <= currentScore) continue;
      if (!best) { best = it; continue; }
      if (it.levelRequired < best.levelRequired) { best = it; continue; }
      if (it.levelRequired === best.levelRequired) {
        if (getScore(it, state.style, state.subStat) > getScore(best, state.style, state.subStat)) best = it;
      }
    }
    return best;
  }

  function getDisplayItem(slot) {
    if (state.locked[slot]) return state.lockedItems[slot];
    if (state.mode === 'Current') return getBIS(slot);
    return getNextBIS(slot) || getBIS(slot);
  }

  function getEffectiveDisplayItem(slot) {
    if (slot === 'shield') {
      var weapon = getDisplayItem('weapon');
      if (weapon && weapon.twoHanded) return null;
    }
    return getDisplayItem(slot);
  }

  function fetchIcon(itemId, callback) {
    if (state.iconCache[itemId]) { callback(state.iconCache[itemId]); return; }
    if (state.iconCache[itemId] === null) { callback(null); return; }
    fetch('/api.php?action=query&titles=File:Item_'+itemId+'.png&prop=imageinfo&iiprop=url&format=json')
      .then(function(r){return r.json();})
      .then(function(data){
        var pages = data&&data.query&&data.query.pages;
        if (!pages) { state.iconCache[itemId]=null; callback(null); return; }
        var page = Object.values(pages)[0];
        var url = page&&page.imageinfo&&page.imageinfo[0]&&page.imageinfo[0].url;
        state.iconCache[itemId] = url||null;
        callback(state.iconCache[itemId]);
      })
      .catch(function(){ state.iconCache[itemId]=null; callback(null); });
  }

  function el(tag, attrs, children) {
    var e = document.createElement(tag);
    if (attrs) Object.keys(attrs).forEach(function(k){
      if (k==='style'&&typeof attrs[k]==='object') Object.assign(e.style, attrs[k]);
      else if (k==='className') e.className=attrs[k];
      else if (k==='textContent') e.textContent=attrs[k];
      else e.setAttribute(k, attrs[k]);
    });
    if (children) [].concat(children).forEach(function(c){ if(c) e.appendChild(typeof c==='string'?document.createTextNode(c):c); });
    return e;
  }

  function getRootWidth() {
    var root = document.getElementById('eq-bis-root');
    if (!root) return DESIGN_WIDTH;
    return root.getBoundingClientRect().width || root.offsetWidth || DESIGN_WIDTH;
  }

  // Helper: attach a click handler that prevents default, stops propagation,
  // blurs the element afterwards, and preserves the page scroll position.
  // This avoids the browser auto-scrolling to a focused/clicked element on re-render.
  function onClick(elNode, fn) {
    elNode.addEventListener('click', function(e){
      e.preventDefault();
      e.stopPropagation();
      var sx = window.scrollX, sy = window.scrollY;
      fn(e);
      if (elNode.blur) elNode.blur();
      if (document.activeElement && document.activeElement.blur) document.activeElement.blur();
      window.scrollTo(sx, sy);
    });
  }

  function render() {
    var root = document.getElementById('eq-bis-root');
    if (!root) return;

    root._exListScroll = root._exListScroll || 0;
    root._mobListScroll = root._mobListScroll || 0;

    // Preserve page scroll position across re-renders (innerHTML reset can shift layout)
    var pageScrollX = window.scrollX, pageScrollY = window.scrollY;

    root.innerHTML = '';

    var availWidth = getRootWidth();
    var scale = Math.min(1, availWidth / DESIGN_WIDTH);

    // Outer wrapper: uses padding-bottom trick to reserve scaled height without JS measurement
    var outerWrap = el('div', {style:{
      width: '100%',
      position: 'relative',
      overflow: 'hidden'
    }});

    var wrap = el('div',{style:{
      background:BG, color:TEXT, fontFamily:'inherit', fontSize:'12px',
      padding:'12px', borderRadius:'8px', boxSizing:'border-box',
      width: DESIGN_WIDTH+'px',
      position:'relative',
      transformOrigin:'top left',
      transform:'scale('+scale+')'
    }});

    if (state.loading) {
      wrap.appendChild(el('div',{style:{textAlign:'center',padding:'40px',color:TEXT_DIM},textContent:'Loading item data...'}));
      outerWrap.appendChild(wrap);
      root.appendChild(outerWrap);
      outerWrap.style.height = Math.round(80 * scale)+'px';
      window.scrollTo(pageScrollX, pageScrollY);
      return;
    }

    wrap.appendChild(el('div',{style:{position:'absolute',top:'8px',right:'12px',fontSize:'9px',color:TEXT_DIM}},'Made by MANGO, 2026'));

    // ── MAIN LAYOUT ──
    // Three columns: left sidebar (style/skills/exclude), center (mode+filters / equipment + totals), right sidebar (tips/progress/mob)
    var mainGrid = el('div',{style:{display:'grid',gridTemplateColumns:'170px 1fr 230px',gap:'8px',alignItems:'start',paddingTop:'8px'}});

    // ── LEFT SIDEBAR ──
    var leftCol=el('div',{style:{display:'flex',flexDirection:'column',gap:'8px'}});

    var stylePanel=makePanel();
    stylePanel.appendChild(makeSectionHeader('Combat Style'));
    var styleBar=el('div',{style:{display:'flex',flexDirection:'column',gap:'4px'}});
    STYLES.forEach(function(s){
      var active=state.style===s;
      var b=el('button',{style:{background:active?RED_LIGHT:SURFACE,border:'1px solid '+(active?BORDER:BORDER_DIM),borderRadius:'6px',color:active?TEXT:TEXT_DIM,padding:'4px 10px',fontSize:'11px',cursor:'pointer',width:'100%'}},s);
      onClick(b, function(s){ return function(){ state.style=s; state.subStat='Auto'; render(); }; }(s));
      styleBar.appendChild(b);
    });
    stylePanel.appendChild(styleBar);

    var subs=SUBSTATS[state.style]||[];
    if (subs.length>1) {
      var subBar=el('div',{style:{display:'flex',flexDirection:'column',gap:'3px',marginTop:'6px'}});
      subs.forEach(function(ss){
        var active=state.subStat===ss;
        var b=el('button',{style:{background:active?RED_LIGHT:SURFACE,border:'1px solid '+(active?BORDER:BORDER_DIM),borderRadius:'5px',color:active?TEXT:TEXT_DIM,padding:'2px 7px',fontSize:'10px',cursor:'pointer',width:'100%'}},ss);
        onClick(b, function(ss){ return function(){ state.subStat=ss; render(); }; }(ss));
        subBar.appendChild(b);
      });
      stylePanel.appendChild(subBar);
    }
    leftCol.appendChild(stylePanel);

    // Skills panel: narrower, less height, stacked rows
    var skillsPanel = makePanel();
    skillsPanel.appendChild(makeSectionHeader('Skills'));
    var skillStack=el('div',{style:{display:'flex',flexDirection:'column',gap:'3px'}});
    SKILLS.forEach(function(sk){
      var cell=el('div',{style:{display:'flex',alignItems:'center',gap:'4px'}});
      cell.appendChild(el('label',{style:{fontSize:'9px',color:TEXT_DIM,flex:'1',whiteSpace:'nowrap',overflow:'hidden',textOverflow:'ellipsis'}},sk));
      var inp=el('input',{type:'text',inputmode:'numeric',pattern:'[0-9]*',id:'eq-skill-'+sk.replace(/\s+/g,'-'),value:state.skills[sk]||1,style:{background:BG,border:'1px solid '+BORDER_DIM,borderRadius:'4px',color:TEXT,padding:'2px 4px',fontSize:'11px',width:'48px',boxSizing:'border-box',fontFamily:'inherit',flexShrink:'0'}});
      // FIX: oninput only updates state, does NOT call render() — prevents DOM replacement mid-type which caused cursor to jump to position 0
      inp.oninput=(function(s){ return function(){ state.skills[s]=Math.min(150,Math.max(1,parseInt(this.value)||1)); }; })(sk);
      inp.onblur=(function(s){ return function(){ render(); }; })(sk);
      inp.onkeydown=(function(s){ return function(e){ if(e.key==='Enter'){ this.blur(); } }; })(sk);
      cell.appendChild(inp);
      skillStack.appendChild(cell);
    });
    skillsPanel.appendChild(skillStack);

    if (state.mode==='Next') {
      var rangeLabelEl=el('div',{style:{fontSize:'10px',color:TEXT_DIM,marginTop:'6px',marginBottom:'2px'}},'+'+state.range+' levels');
      var rangeInp=el('input',{type:'range',min:'1',max:'50',value:state.range,style:{width:'100%',accentColor:RED_LIGHT}});
      rangeInp.oninput=function(){ state.range=parseInt(this.value); rangeLabelEl.textContent='+'+state.range+' levels'; };
      rangeInp.onchange=function(){ state.range=parseInt(this.value); render(); };
      skillsPanel.appendChild(rangeLabelEl);
      skillsPanel.appendChild(rangeInp);
    }
    leftCol.appendChild(skillsPanel);

    // Exclude items panel (moved here, narrower)
    var exPanel=makePanel();
    exPanel.appendChild(makeSectionHeader('Exclude Items'));
    var exSearch=el('input',{type:'text',placeholder:'Search items...',value:state.itemSearch,style:{background:BG,border:'1px solid '+BORDER_DIM,borderRadius:'4px',color:TEXT,padding:'3px 6px',fontSize:'10px',width:'100%',boxSizing:'border-box',fontFamily:'inherit',marginBottom:'4px'}});
    exSearch.oninput=function(){ state.itemSearch=this.value; renderExList(); };
    exPanel.appendChild(exSearch);
    var exList=el('div',{style:{maxHeight:'160px',overflowY:'auto'}});
    exList.addEventListener('scroll',function(){ root._exListScroll=exList.scrollTop; });
    function renderExList(){
      exList.innerHTML='';
      var q=(state.itemSearch||'').toLowerCase();
      var excluded=[],rest=[];
      for(var i=0;i<state.items.length;i++){
        var it=state.items[i];
        if(!it.equippable) continue;
        if(q&&it.name.toLowerCase().indexOf(q)<0) continue;
        if(state.excluded[it.name]) excluded.push(it); else rest.push(it);
      }
      excluded.concat(rest).slice(0,30).forEach(function(it){
        var isEx=!!state.excluded[it.name];
        var lbl=el('label',{style:{display:'flex',alignItems:'center',gap:'4px',fontSize:'9px',color:isEx?TEXT:TEXT_DIM,cursor:'pointer',padding:'1px 0'}});
        var chk=el('input',{type:'checkbox',style:{accentColor:RED_LIGHT}});
        chk.checked=isEx;
        chk.onchange=(function(name){ return function(e){ e.preventDefault(); if(this.checked) state.excluded[name]=true; else delete state.excluded[name]; render(); }; })(it.name);
        lbl.appendChild(chk);
        lbl.appendChild(document.createTextNode(it.name));
        exList.appendChild(lbl);
      });
      exList.scrollTop=root._exListScroll||0;
    }
    renderExList();
    exPanel.appendChild(exList);
    leftCol.appendChild(exPanel);

    mainGrid.appendChild(leftCol);

    // ── CENTER COLUMN: Mode+Filters row, then equipment grid (centered) + totals ──
    var centerCol=el('div',{style:{display:'flex',flexDirection:'column',gap:'5px',alignItems:'center'}});

    // Mode + Filters row (shoulders of equipment grid)
    var topRowWrap=el('div',{style:{display:'flex',justifyContent:'space-between',width:'460px',gap:'8px'}});

    var modePanel=makePanel();
    modePanel.style.flex='1';
    modePanel.appendChild(makeSectionHeader('Mode'));
    var modeBar = el('div',{style:{display:'flex',flexDirection:'column',gap:'4px'}});
    [['Current Best in Slot','Current'],['Next Best in Slot','Next']].forEach(function(pair){
      var label=pair[0], val=pair[1], active=state.mode===val;
      var b=el('button',{style:{background:active?RED_LIGHT:SURFACE,border:'1px solid '+(active?BORDER:BORDER_DIM),borderRadius:'6px',color:active?TEXT:TEXT_DIM,padding:'4px 10px',fontSize:'11px',cursor:'pointer',width:'100%'}},label);
      onClick(b, function(val){ return function(){ state.mode=val; render(); }; }(val));
      modeBar.appendChild(b);
    });
    modePanel.appendChild(modeBar);
    topRowWrap.appendChild(modePanel);

    var filterPanel=makePanel();
    filterPanel.style.flex='1';
    filterPanel.appendChild(makeSectionHeader('Filters'));
    var filterBar=el('div',{style:{display:'flex',flexDirection:'column',gap:'4px'}});
    var no2hBtn=el('button',{style:{background:state.no2h?RED_LIGHT:SURFACE,border:'1px solid '+(state.no2h?BORDER:BORDER_DIM),borderRadius:'6px',color:state.no2h?TEXT:TEXT_DIM,padding:'4px 10px',fontSize:'11px',cursor:'pointer',width:'100%'}},'No 2-handed Weapon');
    onClick(no2hBtn, function(){ state.no2h=!state.no2h; render(); });
    filterBar.appendChild(no2hBtn);
    var noHQBtn=el('button',{style:{background:state.noHQ?RED_LIGHT:SURFACE,border:'1px solid '+(state.noHQ?BORDER:BORDER_DIM),borderRadius:'6px',color:state.noHQ?TEXT:TEXT_DIM,padding:'4px 10px',fontSize:'11px',cursor:'pointer',width:'100%'}},'No HQ');
    onClick(noHQBtn, function(){ state.noHQ=!state.noHQ; render(); });
    filterBar.appendChild(noHQBtn);
    filterPanel.appendChild(filterBar);
    topRowWrap.appendChild(filterPanel);

    centerCol.appendChild(topRowWrap);

    var equipWrap=el('div',{style:{display:'flex',flexDirection:'column',gap:'5px',width:'460px'}});

    function makeSlotBox(slot) {
      var item=getEffectiveDisplayItem(slot);
      var isLocked=!!state.locked[slot];
      var isNext=state.mode==='Next'&&getNextBIS(slot)&&!isLocked;
      var borderCol=isLocked?BORDER:(isNext?RED_LIGHT:BORDER_DIM);
      var borderW=isLocked?'2px':'1px';

      var box=el('div',{style:{background:SURFACE,border:borderW+' solid '+borderCol,borderRadius:'6px',padding:'5px',height:'80px',cursor:'pointer',position:'relative',overflow:'visible',display:'flex',flexDirection:'column',gap:'2px',boxSizing:'border-box'}});

      if(isLocked) box.appendChild(el('div',{style:{position:'absolute',top:'2px',right:'3px',fontSize:'7px',color:BORDER,background:SURFACE,padding:'1px 3px',borderRadius:'3px'}},'LOCKED'));
      box.appendChild(el('div',{style:{fontSize:'8px',color:TEXT_DIM,textTransform:'uppercase',letterSpacing:'0.05em'}},SLOT_LABELS[slot]));

      var innerWrap=el('div',{style:{flex:'1',display:'flex',flexDirection:'column',gap:'2px',overflow:'hidden'}});

      if(item){
        var topRow=el('div',{style:{display:'flex',alignItems:'center',gap:'4px'}});
        var iconWrap=el('div',{style:{width:'28px',height:'28px',background:BG,borderRadius:'3px',display:'flex',alignItems:'center',justifyContent:'center',flexShrink:'0'}});
        topRow.appendChild(iconWrap);
        var nameWrap=el('div',{style:{flex:'1',minWidth:'0'}});
        nameWrap.appendChild(el('div',{style:{fontSize:'9px',color:TEXT,fontWeight:'500',overflow:'hidden',textOverflow:'ellipsis',whiteSpace:'nowrap'}},item.name));
        if(item.levelRequired) nameWrap.appendChild(el('div',{style:{fontSize:'8px',color:TEXT_DIM}},'Lv '+item.levelRequired+' '+(item.equipSkill||'')));
        topRow.appendChild(nameWrap);
        innerWrap.appendChild(topRow);

        fetchIcon(item.id,function(url){
          if(url){ var img=el('img',{src:url,alt:item.name,style:{width:'28px',height:'28px',objectFit:'contain'}}); iconWrap.innerHTML=''; iconWrap.appendChild(img); }
        });

        var statsDiv=el('div',{style:{borderTop:'1px solid '+BORDER_DIM,paddingTop:'1px',flex:'1',overflowY:'auto'}});
        var statPairs=[
          ['stabAttack','Stab Atk'],['slashAttack','Slash Atk'],['crushAttack','Crush Atk'],
          ['rangedAccuracy','Rng Acc'],['magicAccuracy','Mag Acc'],
          ['stabDefence','Stab Def'],['slashDefence','Slash Def'],['crushDefence','Crush Def'],
          ['rangedDefence','Rng Def'],['magicDefence','Mag Def'],
          ['meleeStrength','Mel Str'],['rangedStrength','Rng Str']
        ];
        statPairs.forEach(function(pair){
          var v=item[pair[0]];
          if(!v) return;
          var row=el('div',{style:{display:'flex',justifyContent:'space-between',fontSize:'9px',padding:'0'}});
          row.appendChild(el('span',{style:{color:TEXT_DIM}},pair[1]));
          row.appendChild(el('span',{style:{color:v>0?GREEN:TEXT,fontWeight:'500'}},(v>0?'+':'')+v));
          statsDiv.appendChild(row);
        });
        innerWrap.appendChild(statsDiv);
      } else {
        innerWrap.appendChild(el('div',{style:{flex:'1',display:'flex',alignItems:'center',justifyContent:'center',color:BORDER_DIM,fontSize:'10px'}},'Empty'));
      }
      box.appendChild(innerWrap);

      onClick(box, function(){
        if(state.menuOpenSlot===slot){ state.menuOpenSlot=null; render(); return; }
        state.menuOpenSlot=slot; render();
      });
      box.oncontextmenu=function(e){
        e.preventDefault(); e.stopPropagation();
        if(item){ state.excluded[item.name]=true; state.itemSearch=''; }
        render();
      };

      if(state.menuOpenSlot===slot){
        var menu=el('div',{style:{position:'absolute',top:'100%',left:'0',marginTop:'2px',background:SURFACE,border:'1px solid '+BORDER,borderRadius:'6px',zIndex:'20',display:'flex',flexDirection:'column',minWidth:'120px',boxShadow:'0 2px 8px rgba(0,0,0,0.5)'}});
        menu.addEventListener('click',function(e){ e.stopPropagation(); });

        var lockBtn=el('button',{style:{background:'transparent',border:'none',color:TEXT,padding:'6px 10px',fontSize:'11px',cursor:'pointer',textAlign:'left'}},(state.locked[slot]?'Unlock Slot':'Lock Slot'));
        onClick(lockBtn, function(){
          if(state.locked[slot]){ delete state.locked[slot]; delete state.lockedItems[slot]; }
          else if(item){ state.locked[slot]=true; state.lockedItems[slot]=item; }
          state.menuOpenSlot=null; render();
        });
        menu.appendChild(lockBtn);

        var wikiBtn=el('button',{style:{background:'transparent',border:'none',color:TEXT,padding:'6px 10px',fontSize:'11px',cursor:item?'pointer':'default',textAlign:'left',opacity:item?'1':'0.4'}},'Open Wiki');
        onClick(wikiBtn, function(){
          if(item) window.open('https://evilquest.wiki/w/'+encodeURIComponent(item.name.replace(/ /g,'_')),'_blank');
          state.menuOpenSlot=null; render();
        });
        menu.appendChild(wikiBtn);
        box.appendChild(menu);
      }
      return box;
    }

    function makeRow(slots){
      var row=el('div',{style:{display:'grid',gridTemplateColumns:slots.map(function(){return'1fr';}).join(' '),gap:'5px'}});
      slots.forEach(function(s){ row.appendChild(s===null?el('div'):makeSlotBox(s)); });
      return row;
    }

    equipWrap.appendChild(makeRow([null,'head',null]));
    equipWrap.appendChild(makeRow(['cape','neck','ammo']));
    equipWrap.appendChild(makeRow(['weapon','body','shield']));
    equipWrap.appendChild(makeRow(['hands','legs','ring']));
    equipWrap.appendChild(makeRow([null,'feet',null]));

    centerCol.appendChild(equipWrap);

    // Total bonuses below equipment
    var totPanel=makePanel();
    totPanel.style.width='460px';
    totPanel.style.boxSizing='border-box';
    totPanel.appendChild(makeSectionHeader('Total Bonuses'));
    var totGrid=el('div',{style:{display:'grid',gridTemplateColumns:'repeat(3,1fr)',gap:'2px 8px'}});
    STAT_KEYS.forEach(function(k){
      var total=0;
      SLOTS.forEach(function(slot){ var it=getEffectiveDisplayItem(slot); if(it) total+=(it[k]||0); });
      var row=el('div',{style:{display:'flex',justifyContent:'space-between',fontSize:'9px'}});
      row.appendChild(el('span',{style:{color:TEXT_DIM}},STAT_LABELS[k]));
      row.appendChild(el('span',{style:{color:total>0?GREEN:TEXT}},(total>0?'+':'')+total));
      totGrid.appendChild(row);
    });
    totPanel.appendChild(totGrid);
    centerCol.appendChild(totPanel);

    mainGrid.appendChild(centerCol);

    // ── RIGHT SIDEBAR ──
    var rightCol=el('div',{style:{display:'flex',flexDirection:'column',gap:'8px'}});

    // Tips panel
    var tipsPanel=makePanel();
    var tipsWrap=el('div',{style:{fontSize:'10px',color:TEXT_DIM,lineHeight:'1.6'}});
    tipsWrap.appendChild(el('div',{style:{fontSize:'9px',color:TEXT_DIM,textTransform:'uppercase',letterSpacing:'0.08em',marginBottom:'6px',fontWeight:'600'}},'Tips'));
    tipsWrap.appendChild(el('div',{style:{marginBottom:'4px'}},'Left click a slot to Lock Slot / Open Wiki'));
    tipsWrap.appendChild(el('div',{style:{marginBottom:'4px'}},'Right click a slot to exclude an item'));
    tipsWrap.appendChild(el('div',null,'Choose a mob in the Mob Selector to see kills needed for Next BIS'));
    tipsPanel.appendChild(tipsWrap);
    rightCol.appendChild(tipsPanel);

    // Next BIS Progress
    if(state.mode==='Next'){
      var progPanel=makePanel();
      progPanel.appendChild(makeSectionHeader('Next BIS Progress'));
      var relevantSkills=STYLE_SKILLS[state.style]||[];
      var anyBar=false;
      relevantSkills.forEach(function(sk){
        var curLevel=null, nextLevel=null;
        SLOTS.forEach(function(slot){
          var cur=getBIS(slot);
          if(cur&&cur.equipSkill&&skillKeyToStateKey(cur.equipSkill)===sk&&cur.levelRequired){
            if(curLevel===null||cur.levelRequired>curLevel) curLevel=cur.levelRequired;
          }
          var nxt=getNextBIS(slot);
          if(nxt&&nxt.equipSkill&&skillKeyToStateKey(nxt.equipSkill)===sk&&nxt.levelRequired){
            if(nextLevel===null||nxt.levelRequired<nextLevel) nextLevel=nxt.levelRequired;
          }
        });
        if(curLevel===null) curLevel=1;
        if(nextLevel===null) return;
        anyBar=true;
        var curXp=levelToXp(state.skills[sk]||1);
        var curBisXp=levelToXp(curLevel);
        var nextBisXp=levelToXp(nextLevel);
        var total=nextBisXp-curBisXp;
        var progressed=curXp-curBisXp;
        var pct=total>0?Math.min(100,Math.max(0,Math.round((progressed/total)*100))):100;
        var xpLeft=Math.max(0,nextBisXp-curXp);
        var pb=el('div',{style:{marginBottom:'8px'}});
        var hdr=el('div',{style:{display:'flex',justifyContent:'space-between',fontSize:'9px',color:TEXT_DIM,marginBottom:'2px'}});
        var lvlRow=el('span');
        lvlRow.appendChild(document.createTextNode(sk+': Lv '+curLevel));
        lvlRow.appendChild(el('span',{style:{margin:'0 3px'}},'→'));
        lvlRow.appendChild(document.createTextNode('Lv '+nextLevel));
        hdr.appendChild(lvlRow);
        hdr.appendChild(el('span',null,pct+'%'));
        pb.appendChild(hdr);
        var track=el('div',{style:{height:'4px',background:BORDER_DIM,borderRadius:'2px'}});
        track.appendChild(el('div',{style:{height:'100%',width:pct+'%',background:GREEN,borderRadius:'2px'}}));
        pb.appendChild(track);
        pb.appendChild(el('div',{style:{fontSize:'8px',color:TEXT_DIM,marginTop:'2px'}},xpLeft.toLocaleString()+' XP left'));
        progPanel.appendChild(pb);
      });
      if(!anyBar) progPanel.appendChild(el('div',{style:{fontSize:'10px',color:TEXT_DIM,textAlign:'center',padding:'6px'}},'No upgrades in range.'));
      rightCol.appendChild(progPanel);
    }

    // Mob selector
    var mobPanel=makePanel();
    mobPanel.appendChild(makeSectionHeader('Mob Selector'));
    var mobSrch=el('input',{type:'text',placeholder:'Search mobs...',value:state.mobSearch,style:{background:BG,border:'1px solid '+BORDER_DIM,borderRadius:'4px',color:TEXT,padding:'3px 6px',fontSize:'10px',width:'100%',boxSizing:'border-box',fontFamily:'inherit',marginBottom:'4px'}});
    mobSrch.oninput=function(){ state.mobSearch=this.value; renderMobList(); };
    mobPanel.appendChild(mobSrch);
    var mobList=el('div',{style:{maxHeight:'120px',overflowY:'auto'}});
    mobList.addEventListener('scroll',function(){ root._mobListScroll=mobList.scrollTop; });
    function renderMobList(){
      mobList.innerHTML='';
      var q=(state.mobSearch||'').toLowerCase();
      if(state.loadingNpcs){ mobList.appendChild(el('div',{style:{color:TEXT_DIM,fontSize:'10px',textAlign:'center',padding:'8px'}},'Loading...')); return; }
      var mobs=state.npcs.filter(function(n){
        if(!n.health||n.health<=0) return false;
        if(EXCLUDED_NPCS.indexOf((n.name||'').toLowerCase())>=0) return false;
        if(q&&n.name.toLowerCase().indexOf(q)<0) return false;
        return true;
      });
      if(!mobs.length){ mobList.appendChild(el('div',{style:{color:TEXT_DIM,fontSize:'10px',textAlign:'center',padding:'8px'}},'No mobs found')); return; }
      mobs.slice(0,25).forEach(function(n){
        var isSel=state.selectedMob&&state.selectedMob.name===n.name;
        var row=el('div',{style:{padding:'3px 6px',borderRadius:'4px',cursor:'pointer',fontSize:'10px',background:isSel?RED_LIGHT:'transparent',color:isSel?TEXT:TEXT_DIM}});
        row.textContent=n.name+' ('+n.health+' HP)';
        onClick(row, function(n){ return function(){ state.selectedMob=n; render(); }; }(n));
        mobList.appendChild(row);
      });
      mobList.scrollTop=root._mobListScroll||0;
    }
    renderMobList();
    mobPanel.appendChild(mobList);

    if(state.selectedMob&&state.mode==='Next'){
      var relevantSkillsK=STYLE_SKILLS[state.style]||[];
      relevantSkillsK.forEach(function(sk){
        var worstKills=0;
        SLOTS.forEach(function(slot){
          var nxt=getNextBIS(slot);
          if(!nxt||!nxt.levelRequired||!nxt.equipSkill) return;
          if(skillKeyToStateKey(nxt.equipSkill)!==sk) return;
          var curXp=levelToXp(state.skills[sk]||1);
          var gap=Math.max(0,levelToXp(nxt.levelRequired)-curXp);
          var kills=Math.ceil(gap/5/state.selectedMob.health);
          if(kills>worstKills) worstKills=kills;
        });
        var cell=el('div',{style:{textAlign:'center',padding:'6px 4px',borderTop:'1px solid '+BORDER_DIM,marginTop:'4px'}});
        cell.appendChild(el('div',{style:{fontSize:'8px',color:TEXT_DIM,textTransform:'uppercase',letterSpacing:'0.06em',marginBottom:'2px'}},sk));
        if(worstKills>0){
          cell.appendChild(el('div',{style:{fontSize:'20px',fontWeight:'500',color:TEXT,lineHeight:'1.1'}},worstKills.toLocaleString()));
          cell.appendChild(el('div',{style:{fontSize:'8px',color:TEXT_DIM,marginTop:'1px'}},state.selectedMob.name+' kills for Next BIS'));
        } else {
          cell.appendChild(el('div',{style:{color:GREEN,fontSize:'12px',fontWeight:'500'}},'Already BIS'));
        }
        mobPanel.appendChild(cell);
      });
    }
    rightCol.appendChild(mobPanel);

    mainGrid.appendChild(rightCol);
    wrap.appendChild(mainGrid);
    outerWrap.appendChild(wrap);
    root.appendChild(outerWrap);

    // Set outer height synchronously from measured wrap height
    outerWrap.style.height = Math.round(wrap.offsetHeight * scale)+'px';

    // Restore page scroll position to prevent any browser-driven jump
    window.scrollTo(pageScrollX, pageScrollY);
  }

  function makePanel() {
    return el('div',{style:{background:SURFACE,border:'1px solid '+BORDER_DIM,borderRadius:'8px',padding:'10px'}});
  }
  function makeSectionHeader(text) {
    return el('div',{style:{fontSize:'9px',color:TEXT_DIM,textTransform:'uppercase',letterSpacing:'0.08em',marginBottom:'6px',borderBottom:'1px solid '+BORDER_DIM,paddingBottom:'3px'}},text);
  }

  var resizeTimer;
  window.addEventListener('resize',function(){ clearTimeout(resizeTimer); resizeTimer=setTimeout(render,100); });

  fetch('/index.php?title=Module:ItemData/json&action=raw')
    .then(function(r){return r.json();})
    .then(function(data){ state.items=data; state.loading=false; render(); })
    .catch(function(){ state.loading=false; render(); });

  fetch('/index.php?title=Module:NPCData/json&action=raw')
    .then(function(r){return r.json();})
    .then(function(data){ state.npcs=Array.isArray(data)?data:Object.values(data); state.loadingNpcs=false; render(); })
    .catch(function(){ state.loadingNpcs=false; render(); });

  render();
})();


/* =================== */
/* ===GEAR COMPARE==== */
/* =================== */

(function() {
  if (!document.getElementById('eq-compare-root')) return;

  var DESIGN_WIDTH = 1200;
  var BG='#161414', SURFACE='#1c1b1b', BORDER='#a3a9b1', BORDER_DIM='#2b1211', RED_LIGHT='#5c1a14', TEXT='#e6e6e6', TEXT_DIM='#a3a9b1', GREEN='#4caf50', RED='#e05252';

  var METALS = ['Bronze','Iron','Steel','Black Bronze','Mithril','Crimson','Malachor'];

  var WEAPON_TYPES = ['Dagger','Sword','2-handed Sword','Battle Axe','Axe','Pickaxe','Scimitar','Mace'];
  var ARMOR_TYPES  = ['Cuirass','Plate Mail Body','Plate Mail Legs','Medium Helmet','Full Helmet','Square Shield','Kite Shield'];

  var EXCLUDED_STAT_KEYS = ['value','id','stackable','equipSlot','equipSkill','levelRequired','name','equippable','twoHanded'];

  var STAT_LABELS = {
    stabAttack:'Stab Atk', slashAttack:'Slash Atk', crushAttack:'Crush Atk',
    rangedAccuracy:'Ranged Acc', magicAccuracy:'Magic Acc',
    stabDefence:'Stab Def', slashDefence:'Slash Def', crushDefence:'Crush Def',
    rangedDefence:'Ranged Def', magicDefence:'Magic Def',
    meleeStrength:'Melee Str', rangedStrength:'Ranged Str',
    weight:'Weight', attackSpeed:'Atk Speed'
  };

  var STAT_ORDER = [
    'stabAttack','slashAttack','crushAttack','rangedAccuracy','magicAccuracy',
    'stabDefence','slashDefence','crushDefence','rangedDefence','magicDefence',
    'meleeStrength','rangedStrength','weight','attackSpeed'
  ];

  var state = {
    items: [],
    loading: true,
    iconCache: {},
    category: 'Weapon',  // 'Weapon' | 'Armor'
    // left slot
    leftMetal: 'Bronze', leftType: 'Dagger', leftItem: null, leftHq: false,
    // right slot
    rightMetal: 'Bronze', rightType: 'Dagger', rightItem: null, rightHq: false
  };

  // ── HELPERS ──

  function el(tag, attrs, children) {
    var e = document.createElement(tag);
    if (attrs) Object.keys(attrs).forEach(function(k){
      if (k==='style'&&typeof attrs[k]==='object') Object.assign(e.style, attrs[k]);
      else if (k==='className') e.className=attrs[k];
      else if (k==='textContent') e.textContent=attrs[k];
      else e.setAttribute(k, attrs[k]);
    });
    if (children) [].concat(children).forEach(function(c){ if(c) e.appendChild(typeof c==='string'?document.createTextNode(c):c); });
    return e;
  }

  function onClick(elNode, fn) {
    elNode.addEventListener('click', function(e){
      e.preventDefault(); e.stopPropagation();
      var sx = window.scrollX, sy = window.scrollY;
      fn(e);
      if (elNode.blur) elNode.blur();
      window.scrollTo(sx, sy);
    });
  }

  function getRootWidth() {
    var root = document.getElementById('eq-compare-root');
    if (!root) return DESIGN_WIDTH;
    return root.getBoundingClientRect().width || root.offsetWidth || DESIGN_WIDTH;
  }

  function makePanel() {
    return el('div',{style:{background:SURFACE,border:'1px solid '+BORDER_DIM,borderRadius:'8px',padding:'10px'}});
  }

  function makeSectionHeader(text) {
    return el('div',{style:{fontSize:'9px',color:TEXT_DIM,textTransform:'uppercase',letterSpacing:'0.08em',marginBottom:'6px',borderBottom:'1px solid '+BORDER_DIM,paddingBottom:'3px'}},text);
  }

  function fetchIcon(itemId, callback) {
    if (state.iconCache[itemId]) { callback(state.iconCache[itemId]); return; }
    if (state.iconCache[itemId] === null) { callback(null); return; }
    fetch('/api.php?action=query&titles=File:Item_'+itemId+'.png&prop=imageinfo&iiprop=url&format=json')
      .then(function(r){return r.json();})
      .then(function(data){
        var pages = data&&data.query&&data.query.pages;
        if (!pages) { state.iconCache[itemId]=null; callback(null); return; }
        var page = Object.values(pages)[0];
        var url = page&&page.imageinfo&&page.imageinfo[0]&&page.imageinfo[0].url;
        state.iconCache[itemId] = url||null;
        callback(state.iconCache[itemId]);
      })
      .catch(function(){ state.iconCache[itemId]=null; callback(null); });
  }

  // Build item name from metal + type + hq flag
  function buildItemName(metal, type, hq) {
    if (!metal || !type) return null;
    var name = metal + ' ' + type;
    if (hq) name += ' (HQ)';
    return name;
  }

  // Find item by name, fall back to non-HQ if HQ not found
  function findItem(metal, type, hq) {
    if (!metal || !type) return null;
    var name = buildItemName(metal, type, hq);
    var found = null;
    for (var i=0; i<state.items.length; i++) {
      if (state.items[i].name === name) { found = state.items[i]; break; }
    }
    // fallback: if HQ requested but not found, try non-HQ
    if (!found && hq) {
      var fallback = buildItemName(metal, type, false);
      for (var j=0; j<state.items.length; j++) {
        if (state.items[j].name === fallback) { found = state.items[j]; break; }
      }
    }
    return found;
  }

  // Refresh left/right items from current selections
  function refreshItems() {
    state.leftItem  = findItem(state.leftMetal,  state.leftType,  state.leftHq);
    state.rightItem = findItem(state.rightMetal, state.rightType, state.rightHq);
  }

  // Collect all numeric stat keys present in an item (excluding ignored fields)
  function getStatKeys(item) {
    if (!item) return [];
    var keys = [];
    STAT_ORDER.forEach(function(k) {
      if (item[k] !== undefined && item[k] !== null && item[k] !== 0 && EXCLUDED_STAT_KEYS.indexOf(k) < 0) keys.push(k);
    });
    // also pick up any keys not in STAT_ORDER
    Object.keys(item).forEach(function(k) {
      if (EXCLUDED_STAT_KEYS.indexOf(k) >= 0) return;
      if (STAT_ORDER.indexOf(k) >= 0) return;
      if (typeof item[k] === 'number' && item[k] !== 0) keys.push(k);
    });
    return keys;
  }

  // All stat keys across both items
  function getAllStatKeys(itemA, itemB) {
    var seen = {}, keys = [];
    function add(k) { if (!seen[k]) { seen[k]=true; keys.push(k); } }
    STAT_ORDER.forEach(function(k) {
      var inA = itemA && itemA[k] !== undefined && itemA[k] !== null && EXCLUDED_STAT_KEYS.indexOf(k) < 0;
      var inB = itemB && itemB[k] !== undefined && itemB[k] !== null && EXCLUDED_STAT_KEYS.indexOf(k) < 0;
      if (inA || inB) add(k);
    });
    [itemA, itemB].forEach(function(item) {
      if (!item) return;
      Object.keys(item).forEach(function(k) {
        if (EXCLUDED_STAT_KEYS.indexOf(k) >= 0) return;
        if (typeof item[k] !== 'number') return;
        add(k);
      });
    });
    return keys;
  }

  function randomChoice(arr) {
    return arr[Math.floor(Math.random() * arr.length)];
  }

  // ── RENDER ──

  function render() {
    var root = document.getElementById('eq-compare-root');
    if (!root) return;

    var pageScrollX = window.scrollX, pageScrollY = window.scrollY;
    root.innerHTML = '';

    var availWidth = getRootWidth();
    var scale = Math.min(1, availWidth / DESIGN_WIDTH);

    var outerWrap = el('div',{style:{width:'100%',position:'relative',overflow:'hidden'}});
    var wrap = el('div',{style:{
      background:BG, color:TEXT, fontFamily:'inherit', fontSize:'12px',
      padding:'12px', borderRadius:'8px', boxSizing:'border-box',
      width:DESIGN_WIDTH+'px', position:'relative',
      transformOrigin:'top left', transform:'scale('+scale+')'
    }});

    if (state.loading) {
      wrap.appendChild(el('div',{style:{textAlign:'center',padding:'40px',color:TEXT_DIM},textContent:'Loading item data...'}));
      outerWrap.appendChild(wrap); root.appendChild(outerWrap);
      outerWrap.style.height = Math.round(80*scale)+'px';
      window.scrollTo(pageScrollX, pageScrollY);
      return;
    }

    wrap.appendChild(el('div',{style:{position:'absolute',top:'8px',right:'12px',fontSize:'9px',color:TEXT_DIM}},'Made by MANGO, 2026'));

    refreshItems();

    // ── TOP: Category buttons ──
    var topBar = el('div',{style:{display:'flex',justifyContent:'center',gap:'8px',marginBottom:'10px',paddingTop:'4px'}});
    ['Weapon','Armor'].forEach(function(cat){
      var active = state.category === cat;
      var b = el('button',{style:{
        background: active?RED_LIGHT:SURFACE,
        border:'1px solid '+(active?BORDER:BORDER_DIM),
        borderRadius:'6px', color: active?TEXT:TEXT_DIM,
        padding:'5px 28px', fontSize:'12px', cursor:'pointer', fontFamily:'inherit'
      }}, cat);
      onClick(b, function(cat){ return function(){
        state.category = cat;

        // reset type selections when switching category
  if (cat === 'Weapon') {
    state.leftType = 'Dagger';
    state.rightType = 'Dagger';
  } else {
    state.leftType = 'Cuirass';
    state.rightType = 'Cuirass';
  }

        refreshItems(); render();
      }; }(cat));
      topBar.appendChild(b);
    });
    wrap.appendChild(topBar);

    // ── MAIN LAYOUT: left controls | compare boxes | right controls ──
    var mainGrid = el('div',{style:{display:'grid',gridTemplateColumns:'300px 1fr 300px',gap:'15px',alignItems:'start'}});

    // ── LEFT CONTROLS ──
    var leftCtrl = buildControls('left');
    mainGrid.appendChild(leftCtrl);

    // ── CENTER: two compare boxes side by side ──
    var center = el('div',{style:{display:'flex',flexDirection:'column',gap:'8px',alignItems:'center'}});

    var boxRow = el('div',{style:{display:'flex',gap:'16px',justifyContent:'center',width:'100%'}});
    boxRow.appendChild(buildCompareBox('left',  state.leftItem,  state.rightItem));
    boxRow.appendChild(buildCompareBox('right', state.rightItem, state.leftItem));
    center.appendChild(boxRow);

    // Randomize button below boxes
    var randBtn = el('button',{style:{
      background:SURFACE, border:'1px solid '+BORDER_DIM, borderRadius:'6px',
      color:TEXT_DIM, padding:'5px 20px', fontSize:'11px', cursor:'pointer',
      fontFamily:'inherit', marginTop:'4px'
    }}, '⚄ Randomize');
    onClick(randBtn, function(){
      var types = state.category === 'Weapon' ? WEAPON_TYPES : ARMOR_TYPES;
      state.leftMetal  = randomChoice(METALS);
      state.rightMetal = randomChoice(METALS);
      state.leftType   = randomChoice(types);
      state.rightType  = randomChoice(types);
      state.leftHq     = Math.random() < 0.5;
      state.rightHq    = Math.random() < 0.5;
      refreshItems(); render();
    });
    center.appendChild(randBtn);

    mainGrid.appendChild(center);

    // ── RIGHT CONTROLS ──
    var rightCtrl = buildControls('right');
    mainGrid.appendChild(rightCtrl);

    wrap.appendChild(mainGrid);
    outerWrap.appendChild(wrap);
    root.appendChild(outerWrap);
    outerWrap.style.height = Math.round(wrap.offsetHeight * scale)+'px';
    window.scrollTo(pageScrollX, pageScrollY);
  }

  // Build the left or right control sidebar
  function buildControls(side) {
    var col = el('div',{style:{display:'flex',flexDirection:'column',gap:'8px'}});

    var currentMetal = side==='left' ? state.leftMetal  : state.rightMetal;
    var currentType  = side==='left' ? state.leftType   : state.rightType;

    // Metal panel
    var metalPanel = makePanel();
    metalPanel.appendChild(makeSectionHeader((side==='left'?'Left':'Right')+' — Metal'));

    // 2-col grid for first 6, then centered last one
    var metalGrid = el('div',{style:{display:'grid',gridTemplateColumns:'1fr 1fr',gap:'3px',marginBottom:'3px'}});
    METALS.slice(0,6).forEach(function(m){
      var active = currentMetal === m;
      var b = el('button',{style:{
        background:active?RED_LIGHT:BG,
        border:'1px solid '+(active?BORDER:BORDER_DIM),
        borderRadius:'5px', color:active?TEXT:TEXT_DIM,
        padding:'3px 0', fontSize:'10px', cursor:'pointer',
        fontFamily:'inherit', width:'100%'
      }}, m);
      onClick(b, function(m,s){ return function(){
        if(s==='left') state.leftMetal=m; else state.rightMetal=m;
        refreshItems(); render();
      }; }(m, side));
      metalGrid.appendChild(b);
    });
    metalPanel.appendChild(metalGrid);

    // Last metal centered
    var lastMetal = METALS[6];
    var lastActive = currentMetal === lastMetal;
    var lastBtn = el('button',{style:{
      background:lastActive?RED_LIGHT:BG,
      border:'1px solid '+(lastActive?BORDER:BORDER_DIM),
      borderRadius:'5px', color:lastActive?TEXT:TEXT_DIM,
      padding:'3px 0', fontSize:'10px', cursor:'pointer',
      fontFamily:'inherit', width:'100%'
    }}, lastMetal);
    onClick(lastBtn, function(m,s){ return function(){
      if(s==='left') state.leftMetal=m; else state.rightMetal=m;
      refreshItems(); render();
    }; }(lastMetal, side));
    metalPanel.appendChild(lastBtn);

    col.appendChild(metalPanel);

    // Type panel — 2-col grid
    var typePanel = makePanel();
    typePanel.appendChild(makeSectionHeader('Type'));
    var types = state.category === 'Weapon' ? WEAPON_TYPES : ARMOR_TYPES;
    var typeGrid = el('div',{style:{display:'grid',gridTemplateColumns:'1fr 1fr',gap:'3px'}});
    types.forEach(function(t){
      var active = currentType === t;
      var b = el('button',{style:{
        background:active?RED_LIGHT:BG,
        border:'1px solid '+(active?BORDER:BORDER_DIM),
        borderRadius:'5px', color:active?TEXT:TEXT_DIM,
        padding:'3px 4px', fontSize:'10px', cursor:'pointer',
        fontFamily:'inherit', width:'100%', textAlign:'center'
      }}, t);
      onClick(b, function(t,s){ return function(){
        if(s==='left') state.leftType=t; else state.rightType=t;
        refreshItems(); render();
      }; }(t, side));
      typeGrid.appendChild(b);
    });
    typePanel.appendChild(typeGrid);
    col.appendChild(typePanel);

    // HQ toggle — per side
    var hqPanel = makePanel();
    hqPanel.appendChild(makeSectionHeader('Options'));
    var currentHq = side==='left' ? state.leftHq : state.rightHq;
    var hqBtn = el('button',{style:{
      background:currentHq?RED_LIGHT:BG,
      border:'1px solid '+(currentHq?BORDER:BORDER_DIM),
      borderRadius:'5px', color:currentHq?TEXT:TEXT_DIM,
      padding:'3px 6px', fontSize:'10px', cursor:'pointer',
      fontFamily:'inherit', width:'100%'
    }}, 'HQ Item');
    onClick(hqBtn, function(s){ return function(){
      if(s==='left') state.leftHq=!state.leftHq; else state.rightHq=!state.rightHq;
      refreshItems(); render();
    }; }(side));
    hqPanel.appendChild(hqBtn);
    col.appendChild(hqPanel);

    return col;
  }

  // Build one compare box (thisItem vs otherItem for coloring)
  function buildCompareBox(side, thisItem, otherItem) {
    var box = el('div',{style:{
      background:SURFACE, border:'1px solid '+BORDER_DIM,
      borderRadius:'8px', padding:'12px',
      width:'300px', minHeight:'300px',
      display:'flex', flexDirection:'column', alignItems:'center', gap:'8px',
      boxSizing:'border-box'
    }});

    if (!thisItem) {
      // Empty state
      var emptyLabel = el('div',{style:{
        flex:'1', display:'flex', flexDirection:'column',
        alignItems:'center', justifyContent:'center', gap:'6px'
      }});
      emptyLabel.appendChild(el('div',{style:{
        width:'64px', height:'64px', background:BG,
        borderRadius:'6px', border:'1px solid '+BORDER_DIM
      }}));
      emptyLabel.appendChild(el('div',{style:{color:BORDER_DIM,fontSize:'11px',textAlign:'center'}},'Select a metal\n& type'));
      box.appendChild(emptyLabel);
      return box;
    }

    // Item name
    box.appendChild(el('div',{style:{
      fontSize:'11px', color:TEXT, fontWeight:'600',
      textAlign:'center', wordBreak:'break-word'
    }}, thisItem.name));

    // Icon
    var iconWrap = el('div',{style:{
      width:'120px', height:'120px', background:BG,
      borderRadius:'6px', border:'1px solid '+BORDER_DIM,
      display:'flex', alignItems:'center', justifyContent:'center', flexShrink:'0'
    }});
    box.appendChild(iconWrap);
    if (thisItem.id) {
      fetchIcon(thisItem.id, function(url){
        if (url) {
          var img = el('img',{src:url, alt:thisItem.name, style:{width:'56px',height:'56px',objectFit:'contain'}});
          iconWrap.innerHTML=''; iconWrap.appendChild(img);
        }
      });
    }

    // Required level info
    if (thisItem.levelRequired && thisItem.equipSkill) {
      box.appendChild(el('div',{style:{fontSize:'9px',color:TEXT_DIM}},
        'Requires Lv '+thisItem.levelRequired+' '+thisItem.equipSkill));
    }

    // Divider
    box.appendChild(el('div',{style:{width:'100%',borderTop:'1px solid '+BORDER_DIM}}));

    // Stats
    var statsWrap = el('div',{style:{width:'100%',display:'flex',flexDirection:'column',gap:'3px'}});
    var allKeys = getAllStatKeys(thisItem, otherItem);

    if (allKeys.length === 0) {
      statsWrap.appendChild(el('div',{style:{color:BORDER_DIM,fontSize:'10px',textAlign:'center'}},'No stats'));
    } else {
      allKeys.forEach(function(k){
        var myVal    = (thisItem  && thisItem[k]  !== undefined) ? thisItem[k]  : null;
        var theirVal = (otherItem && otherItem[k] !== undefined) ? otherItem[k] : null;

        var label = STAT_LABELS[k] || k;
        var displayVal, color;

        if (myVal === null) {
          // Other item has it, we don't
          displayVal = '—';
          color = TEXT_DIM;
        } else if (theirVal === null) {
          // Only we have it
          displayVal = (myVal > 0 ? '+' : '') + myVal;
          color = TEXT;
} else {
  var diff = myVal - theirVal;

  if (k === 'attackSpeed') {
    if (diff < 0) {
      displayVal = myVal + ' (' + diff + ')';
      color = GREEN;
    } else if (diff > 0) {
      displayVal = myVal + ' (+' + diff + ')';
      color = RED;
    } else {
      displayVal = String(myVal);
      color = TEXT;
    }
  } else {
    if (diff > 0) {
      displayVal = (myVal > 0 ? '+' : '') + myVal + ' (+' + diff + ')';
      color = GREEN;
    } else if (diff < 0) {
      displayVal = (myVal > 0 ? '+' : '') + myVal + ' (' + diff + ')';
      color = RED;
    } else {
      displayVal = (myVal > 0 ? '+' : '') + myVal;
      color = TEXT;
    }
  }
}

        var row = el('div',{style:{display:'flex',justifyContent:'space-between',fontSize:'10px',gap:'4px'}});
        row.appendChild(el('span',{style:{color:TEXT_DIM,flexShrink:'0'}}, label));
        row.appendChild(el('span',{style:{color:color,fontWeight:'500',textAlign:'right'}}, displayVal));
        statsWrap.appendChild(row);
      });
    }

    box.appendChild(statsWrap);
    return box;
  }

  // ── INIT ──

  var resizeTimer;
  window.addEventListener('resize', function(){ clearTimeout(resizeTimer); resizeTimer=setTimeout(render,100); });

  fetch('/index.php?title=Module:ItemData/json&action=raw')
    .then(function(r){ return r.json(); })
    .then(function(data){ state.items=data; state.loading=false; render(); })
    .catch(function(){ state.loading=false; render(); });

  render();
})();


/* =================== */
/* ==LIVE DROP TABLE== */
/* =================== */

(function() {
  var dropIconCache = {};

  function fetchDropIcon(itemId, imgElement) {
    if (!itemId || !imgElement) return;
    if (dropIconCache[itemId]) {
      imgElement.src = dropIconCache[itemId];
      imgElement.style.display = 'inline-block';
      return;
    }
    fetch('/api.php?action=query&titles=File:Item_' + itemId + '.png&prop=imageinfo&iiprop=url&format=json')
      .then(function(r) { return r.json(); })
      .then(function(data) {
        var pages = data && data.query && data.query.pages;
        if (!pages) return;
        var page = Object.values(pages)[0];
        if (page && page.imageinfo && page.imageinfo[0] && page.imageinfo[0].url) {
          var url = page.imageinfo[0].url;
          dropIconCache[itemId] = url;
          imgElement.src = url;
          imgElement.style.display = 'inline-block';
        }
      })
      .catch(function() {});
  }

  function hydrateDropTracker($tracker, data, npcName) {
    var totalKills = Number(data.total_kills) || 0;
    var killsFormatted = totalKills.toLocaleString();

    // Update Infobox NPC tracked kill counter if present on page
    if (totalKills > 0) {
      $('.camelkit-npc-kill-row').show();
      $('.camelkit-npc-kill-val').text(killsFormatted);
    }

    // If no drops exist
    if (!data.drops || data.drops.length === 0) {
      if (totalKills > 0) {
        $tracker.html(
          '<div class="mw-message-box mw-message-box-notice camelkit-drops-empty" style="margin-top: 1em; font-style: italic;">' +
          '🛡️ <b>CamelKit Drop Tracker:</b> ' + killsFormatted + ' recorded kill(s), but no item drops recorded yet. Slay this monster in <b>CamelKit</b> to contribute drops!' +
          '</div>'
        );
      }
      return;
    }

    // Build drop table rows
    var rowsHtml = '';
    data.drops.forEach(function(drop) {
      var itemName = drop.item_name || ('Item #' + drop.item_id);
      var pageUrl = '/w/' + encodeURIComponent(itemName.replace(/ /g, '_'));
      var qty = drop.quantity_range || String(drop.min_quantity || 1);

      var rate = Number(drop.drop_rate) || 0;
      var rarity = 'Common';
      var rarityColor = '#2f855a';
      if (rate >= 0.99) {
        rarity = 'Always';
        rarityColor = '#2b6cb0';
      } else if (rate >= 0.10) {
        rarity = 'Common';
        rarityColor = '#2f855a';
      } else if (rate >= 0.02) {
        rarity = 'Uncommon';
        rarityColor = '#d69e2e';
      } else if (rate >= 0.005) {
        rarity = 'Rare';
        rarityColor = '#dd6b20';
      } else {
        rarity = 'Very rare';
        rarityColor = '#e53e3e';
      }

      var rateStr = drop.formatted_rate || '~';
      var ratePct = (drop.drop_rate_pct !== undefined ? drop.drop_rate_pct : (rate * 100)).toFixed(2) + '%';
      var reporters = drop.unique_reporters || 1;
      var reporterBadge = drop.status === 'confirmed'
        ? '<span title="Verified by multiple independent players" style="color: #2f855a; font-weight: bold;">✔ ' + reporters + '</span>'
        : '<span title="Observed report" style="color: #718096;">' + reporters + '</span>';

      rowsHtml += '<tr>' +
        '<td style="font-weight: bold; vertical-align: middle;">' +
          '<img class="camelkit-drop-icon" data-item-id="' + drop.item_id + '" style="width: 20px; height: 20px; object-fit: contain; vertical-align: middle; margin-right: 6px; display: none;" src="" alt="" />' +
          '<a href="' + pageUrl + '" title="' + itemName + '">' + itemName + '</a>' +
        '</td>' +
        '<td style="text-align: center; vertical-align: middle;">' + qty + '</td>' +
        '<td style="text-align: center; vertical-align: middle;">' +
          '<span style="display: inline-block; padding: 2px 8px; border-radius: 4px; font-weight: bold; font-size: 85%; color: white; background-color: ' + rarityColor + ';">' + rarity + '</span>' +
        '</td>' +
        '<td style="text-align: center; vertical-align: middle;" data-sort-value="' + rate + '">' +
          '<b>' + rateStr + '</b> <span style="font-size: 85%; color: #666;">(' + ratePct + ')</span>' +
        '</td>' +
        '<td style="text-align: center; vertical-align: middle;">' + reporterBadge + '</td>' +
      '</tr>';
    });

    var tableHtml =
      '<table class="wikitable sortable camelkit-drops-table" style="width: 100%; border-collapse: collapse; margin-top: 1em;">' +
        '<thead>' +
          '<tr style="background-color: #5c1d1d; color: white;">' +
            '<th style="text-align: left; padding: 6px 10px;">Item</th>' +
            '<th style="width: 100px; text-align: center; padding: 6px 10px;">Quantity</th>' +
            '<th style="width: 120px; text-align: center; padding: 6px 10px;">Rarity</th>' +
            '<th style="width: 140px; text-align: center; padding: 6px 10px;">Drop Rate</th>' +
            '<th style="width: 110px; text-align: center; padding: 6px 10px;">Reporters</th>' +
          '</tr>' +
        '</thead>' +
        '<tbody>' + rowsHtml + '</tbody>' +
      '</table>' +
      '<div class="camelkit-drop-footer" style="display: flex; align-items: center; justify-content: space-between; font-size: 85%; color: #666; margin-top: 6px; font-style: italic; flex-wrap: wrap; gap: 8px;">' +
        '<div>' +
          '<span style="display: inline-block; width: 7px; height: 7px; border-radius: 50%; background: #22c55e; box-shadow: 0 0 5px #22c55e; margin-right: 5px; vertical-align: middle;" title="Live real-time crowdsourcing"></span>' +
          'Crowdsourced via <b>CamelKit Drop Tracker</b> &mdash; based on <b>' + killsFormatted + '</b> recorded kills across all players.' +
        '</div>' +
        '<div style="font-size: 90%; color: #888;">' +
          '<a href="#" class="camelkit-refresh-link" style="color: #888; text-decoration: underline; margin-right: 8px;">↻ Refresh</a>' +
          '<a href="https://camelkit.dev" target="_blank" rel="noopener" style="color: #888; text-decoration: underline;">Install CamelKit</a>' +
        '</div>' +
      '</div>';

    $tracker.html(tableHtml);

    // Fetch icons for each drop item
    $tracker.find('.camelkit-drop-icon').each(function() {
      var id = $(this).data('item-id');
      if (id) fetchDropIcon(id, this);
    });

    // Attach refresh button click handler
    $tracker.find('.camelkit-refresh-link').on('click', function(e) {
      e.preventDefault();
      loadDropsForTracker($tracker, npcName);
    });

    // Initialize sortable behavior if jQuery tablesorter is available
    if (window.mw && mw.loader) {
      mw.loader.using('jquery.tablesorter', function() {
        $tracker.find('table.sortable').tablesorter();
      });
    }
  }

  function loadDropsForTracker($tracker, npcName) {
    var apiUrl = 'https://api.camelkit.dev/wiki/drops?npc_name=' + encodeURIComponent(npcName) + '&all=1';
    fetch(apiUrl)
      .then(function(r) { return r.json(); })
      .then(function(data) {
        if (!data || !data.success) return;
        hydrateDropTracker($tracker, data, npcName);
      })
      .catch(function(err) {
        console.warn('[CamelKit Drops] Live hydration fetch failed:', err);
      });
  }

  mw.hook('wikipage.content').add(function($content) {
    var $trackers = $('.camelkit-drop-tracker');
    if (!$trackers.length) return;

    $trackers.each(function() {
      var $tracker = $(this);
      if ($tracker.data('camelkit-hydrated')) return;
      $tracker.data('camelkit-hydrated', true);

      var npcName = $tracker.attr('data-npc-name') || mw.config.get('wgTitle');
      if (!npcName) return;
      npcName = npcName.replace(/_/g, ' ').trim();

      loadDropsForTracker($tracker, npcName);
    });
  });
})();