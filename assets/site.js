(()=>{'use strict';
const $=(s,r=document)=>r.querySelector(s),$$=(s,r=document)=>[...r.querySelectorAll(s)];
const toast=(msg)=>{let t=$('.toast');if(!t){t=document.createElement('div');t.className='toast';document.body.append(t)}t.textContent=msg;t.classList.add('show');clearTimeout(window.__rtToast);window.__rtToast=setTimeout(()=>t.classList.remove('show'),2200)};
const drawerNode=$('.drawer'),drawerOpener=$('[data-open-drawer]');
const drawer=(open)=>{
 if(!drawerNode||!drawerOpener)return;
 document.body.classList.toggle('drawer-open',open);
 drawerNode.setAttribute('aria-hidden',String(!open));
 drawerNode.toggleAttribute('inert',!open);
 drawerOpener.setAttribute('aria-expanded',String(open));
 if(open){requestAnimationFrame(()=>drawerNode.querySelector('button:not([disabled]),a[href]')?.focus())}
 else drawerOpener.focus();
};
const reveal=()=>{const nodes=$$('.reveal:not([data-observed])');nodes.forEach((el,i)=>{el.dataset.observed='1';el.style.setProperty('--delay',Math.min(i%7,6)*65+'ms')});if(!('IntersectionObserver'in window)){nodes.forEach(n=>n.classList.add('visible'));return}const io=new IntersectionObserver(es=>es.forEach(e=>{if(e.isIntersecting){e.target.classList.add('visible');io.unobserve(e.target)}}),{threshold:.08,rootMargin:'0px 0px -35px'});nodes.forEach(n=>io.observe(n))};
const bar=$('.topline');const progress=()=>{if(!bar)return;const max=document.documentElement.scrollHeight-innerHeight;bar.style.width=(max>0?scrollY/max*100:0)+'%'};
const loadRelease=async()=>{const nodes=$$('[data-latest-release]');if(!nodes.length)return;const dates=$$('[data-release-date]');const fallbacks=nodes.map(n=>n.textContent||'v12.0.0');const setAsset=(kind,asset)=>{const link=$('[data-release-asset="'+kind+'"]');if(!link)return;if(asset&&asset.browser_download_url){link.href=asset.browser_download_url;link.textContent=asset.name+' ↗';link.removeAttribute('aria-disabled')}else{link.href='https://github.com/SilverCrow2323/dolphin-rt-core/releases';link.textContent='No matching asset in this release · browse releases ↗'}};try{const r=await fetch('https://api.github.com/repos/SilverCrow2323/dolphin-rt-core/releases/latest',{headers:{Accept:'application/vnd.github+json'}});if(!r.ok)throw Error();const d=await r.json();if(d.draft||d.prerelease)throw Error();const tag=d.tag_name||'Release available';nodes.forEach(n=>{n.textContent=tag});const link=$('[data-release-link]');if(link&&d.html_url)link.href=d.html_url;if(d.published_at){const published=new Date(d.published_at).toLocaleDateString(undefined,{year:'numeric',month:'short',day:'numeric'});dates.forEach(date=>{date.textContent=published})}const assets=d.assets||[];setAsset('muxupd',assets.find(a=>a.name.toLowerCase().endsWith('.muxupd')));setAsset('appimage',assets.find(a=>a.name.toLowerCase().endsWith('.appimage')));setAsset('rpm',assets.find(a=>a.name.toLowerCase().endsWith('.rpm')))}catch(e){nodes.forEach((node,i)=>{if(!node.textContent)node.textContent=fallbacks[i]||'v12.0.0'})}};
const nav=$('.nav');const active=location.pathname.split('/').pop()||'index.html';$$('.nav a').forEach(a=>{if(a.getAttribute('href')===active){a.classList.add('active');a.setAttribute('aria-current','page')}});
document.addEventListener('click',e=>{const open=e.target.closest('[data-open-drawer]');if(open){drawer(true);return}if(e.target.closest('[data-close-drawer]')||e.target.classList.contains('drawer-backdrop')){drawer(false);return}const copy=e.target.closest('[data-copy]');if(copy){navigator.clipboard?.writeText(copy.dataset.copy).then(()=>toast('Copied to clipboard')).catch(()=>toast('Clipboard unavailable'));return}});
document.addEventListener('keydown',e=>{
 if(e.key==='Escape'&&document.body.classList.contains('drawer-open')){drawer(false);return}
 if(e.key!=='Tab'||!document.body.classList.contains('drawer-open')||!drawerNode)return;
 const focusable=[...drawerNode.querySelectorAll('a[href],button:not([disabled]),input:not([disabled]),select:not([disabled]),textarea:not([disabled]),[tabindex]:not([tabindex="-1"])')];
 if(!focusable.length){e.preventDefault();return}
 const first=focusable[0],last=focusable[focusable.length-1];
 if(e.shiftKey&&(document.activeElement===first||!drawerNode.contains(document.activeElement))){e.preventDefault();last.focus()}
 else if(!e.shiftKey&&(document.activeElement===last||!drawerNode.contains(document.activeElement))){e.preventDefault();first.focus()}
});
document.addEventListener('keydown',event=>{if(event.key!=='Tab')return;const overlays=$$('.detail-overlay.show').filter(node=>node.getAttribute('aria-hidden')==='false');const overlay=overlays[overlays.length-1];if(!overlay)return;const dialog=overlay.querySelector('[role="dialog"][aria-modal="true"]');if(!dialog)return;const focusable=[...dialog.querySelectorAll('a[href],button:not([disabled]),input:not([disabled]),select:not([disabled]),textarea:not([disabled]),[tabindex]:not([tabindex="-1"])')].filter(node=>!node.hidden);if(!focusable.length){event.preventDefault();dialog.focus();return}const first=focusable[0],last=focusable[focusable.length-1];if(event.shiftKey&&(document.activeElement===first||!dialog.contains(document.activeElement))){event.preventDefault();last.focus()}else if(!event.shiftKey&&(document.activeElement===last||!dialog.contains(document.activeElement))){event.preventDefault();first.focus()}});
$$('[data-year]').forEach(n=>n.textContent=new Date().getFullYear());
if('IntersectionObserver'in window)reveal();else reveal();window.addEventListener('scroll',progress,{passive:true});progress();loadRelease();
document.addEventListener('DOMContentLoaded',reveal);
document.addEventListener('click',e=>{const a=e.target.closest('a');if(!a||a.target==='_blank'||a.origin!==location.origin||a.hash||e.metaKey||e.ctrlKey||e.shiftKey||e.altKey)return;const href=a.getAttribute('href');if(!href||href.startsWith('mailto:')||href.startsWith('tel:'))return;e.preventDefault();document.body.classList.add('page-exit');const reduceMotion=window.matchMedia?.('(prefers-reduced-motion: reduce)').matches===true;if(reduceMotion){location.href=href;return}setTimeout(()=>location.href=href,150)});
})();