(()=>{'use strict';
const reader=document.getElementById('magazineReader');
if(!reader)return;
const pages=[...reader.querySelectorAll('.mag-page')];
const prev=document.getElementById('magPrev'),next=document.getElementById('magNext');
const number=document.getElementById('magPageNumber'),total=document.getElementById('magPageTotal'),progress=document.getElementById('magProgress');
let active=0,raf=0;
total.textContent=String(pages.length).padStart(2,'0');
function setActive(index,move=false){
  active=Math.max(0,Math.min(pages.length-1,index));
  if(move){const page=pages[active];reader.scrollTo({left:page.offsetLeft-reader.offsetLeft,behavior:matchMedia('(prefers-reduced-motion: reduce)').matches?'auto':'smooth'});}
  prev.disabled=active===0;next.disabled=active===pages.length-1;
  number.textContent=String(active+1).padStart(2,'0');
  progress.style.width=((active+1)/pages.length*100)+'%';
  pages.forEach((page,i)=>{page.setAttribute('aria-hidden',String(i!==active));page.classList.toggle('is-current',i===active);});
  const target=pages[active].id;
  if(target)history.replaceState(null,'',location.pathname+location.search+'#'+target);
}
function detect(){
  cancelAnimationFrame(raf);
  raf=requestAnimationFrame(()=>{
    const centre=reader.scrollLeft+reader.clientWidth/2;
    let found=0,best=Infinity;
    pages.forEach((page,i)=>{const x=page.offsetLeft+page.offsetWidth/2;const d=Math.abs(x-centre);if(d<best){best=d;found=i}});
    setActive(found,false);
  });
}
prev.addEventListener('click',()=>setActive(active-1,true));
next.addEventListener('click',()=>setActive(active+1,true));
reader.addEventListener('scroll',detect,{passive:true});
reader.addEventListener('keydown',event=>{
  if(['INPUT','TEXTAREA','SELECT'].includes(event.target.tagName))return;
  if(event.key==='ArrowRight'||event.key==='PageDown'){event.preventDefault();setActive(active+1,true)}
  if(event.key==='ArrowLeft'||event.key==='PageUp'){event.preventDefault();setActive(active-1,true)}
  if(event.key==='Home'){event.preventDefault();setActive(0,true)}
  if(event.key==='End'){event.preventDefault();setActive(pages.length-1,true)}
});
document.addEventListener('click',event=>{
  const button=event.target.closest('[data-mag-next],[data-mag-jump]');
  if(!button)return;
  if(button.hasAttribute('data-mag-next'))setActive(active+1,true);
  else setActive(Number(button.dataset.magJump)||0,true);
  if(button.closest('.drawer'))document.querySelector('[data-close-drawer]')?.click();
});
const initialId=decodeURIComponent(location.hash.slice(1));
const initial=pages.findIndex(page=>page.id===initialId);
setActive(initial>=0?initial:0,true);
window.addEventListener('hashchange',()=>{
  const id=decodeURIComponent(location.hash.slice(1));
  const found=pages.findIndex(page=>page.id===id);
  if(found>=0)setActive(found,true);
});
window.addEventListener('resize',()=>setActive(active,true),{passive:true});
})();