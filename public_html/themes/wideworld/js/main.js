(function () {
  'use strict';

  // label yang dibuat lewat JS, mengikuti <html lang> (pilihan bahasa tema);
  // bahasa lain atau tidak dikenal -> Indonesia
  var TEXT = {
    id: { toTop: 'Kembali ke atas', slideOf: '%1 dari %2', image: 'Gambar', close: 'Tutup', prev: 'Sebelumnya', next: 'Berikutnya' },
    en: { toTop: 'Back to top', slideOf: '%1 of %2', image: 'Image', close: 'Close', prev: 'Previous', next: 'Next' }
  };
  var T = TEXT[(document.documentElement.lang || '').toLowerCase().slice(0, 2)] || TEXT.id;

  function ready(fn) {
    if (document.readyState !== 'loading') { fn(); } else { document.addEventListener('DOMContentLoaded', fn); }
  }

  ready(function () {
    var body = document.body;
    var toggle = document.querySelector('.ww-menu-toggle');
    var nav = document.getElementById('ww-nav');
    var header = document.getElementById('masthead');

    // header berbayang ketika halaman di-scroll
    if (header) {
      var onScroll = function () { header.classList.toggle('is-scrolled', window.scrollY > 4); };
      window.addEventListener('scroll', onScroll, { passive: true });
      onScroll();
    }

    // isi kotak cari di header dengan kata kunci yang sedang dicari
    var field = document.getElementById('ww-search-field');
    var m = /[?&]s=([^&#]*)/.exec(location.search);
    if (field && m) {
      try { field.value = decodeURIComponent(m[1].replace(/\+/g, ' ')); } catch (err) { }
    }

    // gambar daftar berita yang gagal dimuat (link mati, mis. CDN Facebook lama) -> placeholder
    var thumbs = document.querySelectorAll('.news-card-thumb img, .ww-thumb img, .ww-hero-media img');
    var toPlaceholder = function (img) {
      var span = document.createElement('span');
      span.className = img.closest('.news-card-thumb') ? 'news-card-noimg' : 'ww-noimg';
      if (img.parentNode) { img.parentNode.replaceChild(span, img); }
    };
    for (var t = 0; t < thumbs.length; t++) {
      (function (img) {
        if (img.complete && img.naturalWidth === 0 && img.getAttribute('src')) { toPlaceholder(img); return; }
        img.addEventListener('error', function () { toPlaceholder(img); });
      })(thumbs[t]);
    }

    initToTop();
    initLightbox();
    var carousels = document.querySelectorAll('.ww-carousel');
    for (var c = 0; c < carousels.length; c++) { initCarousel(carousels[c]); }

    // banner kanan atas: gambar gagal dimuat -> banner itu dibuang;
    // semua gagal -> bagiannya hilang
    var bannerImgs = document.querySelectorAll('.ww-banners-top img');
    var dropBanner = function (img) {
      var item = img.closest('.ww-banner-item'), section = img.closest('.ww-banners-top');
      if (item && item.parentNode) { item.parentNode.removeChild(item); }
      if (section && section.parentNode && !section.querySelector('.ww-banner-item')) { section.parentNode.removeChild(section); }
    };
    for (var bi = 0; bi < bannerImgs.length; bi++) {
      (function (img) {
        if (img.complete && img.naturalWidth === 0 && img.getAttribute('src')) { dropBanner(img); return; }
        img.addEventListener('error', function () { dropBanner(img); });
      })(bannerImgs[bi]);
    }

    if (!toggle || !nav) { return; }

    function setOpen(open) {
      body.classList.toggle('nav-open', open);
      toggle.setAttribute('aria-expanded', open ? 'true' : 'false');
      // panel menempel di bawah bar utama: sisakan tinggi sampai bawah layar
      if (open && header) {
        nav.style.maxHeight = Math.max(200, window.innerHeight - header.getBoundingClientRect().bottom) + 'px';
      } else {
        nav.style.maxHeight = '';
      }
    }

    toggle.addEventListener('click', function () {
      setOpen(!body.classList.contains('nav-open'));
    });

    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape' && body.classList.contains('nav-open')) {
        setOpen(false);
        toggle.focus();
      }
    });

    // tutup menu HP saat layar diperlebar ke ukuran desktop
    var mq = window.matchMedia('(min-width: 900px)');
    var onChange = function (e) { if (e.matches) { setOpen(false); } };
    if (mq.addEventListener) { mq.addEventListener('change', onChange); } else if (mq.addListener) { mq.addListener(onChange); }
  });

  /* ------------------------------------------------------------------------
     Tombol "kembali ke atas" di kanan bawah.
     - dibuat lewat JS: tanpa JS tidak ada tombol yang tidak berfungsi
     - muncul setelah halaman digulir lebih dari satu layar
     - gulir halus, langsung lompat bila "kurangi gerak" aktif
     - fokus keyboard dipindah ke logo/judul di header setelah sampai atas
     ------------------------------------------------------------------------ */
  function initToTop() {
    var btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'ww-totop';
    btn.setAttribute('aria-label', T.toTop);
    btn.innerHTML = '<svg viewBox="0 0 20 20" aria-hidden="true"><path d="M4.5 12.5 10 7l5.5 5.5" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/></svg>';
    document.body.appendChild(btn);

    var update = function () { btn.classList.toggle('is-visible', window.scrollY > window.innerHeight); };
    window.addEventListener('scroll', update, { passive: true });
    update();

    btn.addEventListener('click', function () {
      var reduce = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
      window.scrollTo({ top: 0, behavior: reduce ? 'auto' : 'smooth' });
      var home = document.querySelector('.ww-brand');
      if (home) { home.focus({ preventScroll: true }); }
    });
  }

  /* ------------------------------------------------------------------------
     Banner carousel (markup dari [text mod=wpnews func=herobanner]).
     - kontrol hanya titik; berputar tiap 6 detik
     - berhenti sementara saat kursor di atasnya, saat ada fokus keyboard di
       dalamnya, atau saat tab tidak terlihat
     - berhenti seterusnya begitu pengunjung memilih slide sendiri (klik
       titik, panah keyboard, geser): pengganti tombol jeda
     - "kurangi gerak" aktif -> tidak berputar sendiri
     - gambar yang gagal dimuat -> slide dibuang; semua gagal -> banner hilang
     ------------------------------------------------------------------------ */
  function initCarousel(root) {
    // didefinisikan di sini, bukan di level atas: ready() bisa memanggil
    // initCarousel sebelum baris-baris di bawah IIFE dieksekusi
    var CAROUSEL_DELAY = 6000;

    var track = root.querySelector('.ww-carousel-track');
    var viewport = root.querySelector('.ww-carousel-viewport');
    if (!track || !viewport) { return; }
    var slides = [], current = 0, timer = null;
    var stopped = !!(window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches);
    var hovering = false, focused = false;

    var dots = document.createElement('ul');
    dots.className = 'ww-carousel-dots';
    root.appendChild(dots);

    function rebuild() {
      slides = Array.prototype.slice.call(track.querySelectorAll('.ww-carousel-slide'));
      if (!slides.length) { stop(); if (root.parentNode) { root.parentNode.removeChild(root); } return; }
      if (current >= slides.length) { current = 0; }
      var multi = slides.length > 1;
      dots.hidden = !multi;
      root.classList.toggle('is-single', !multi);
      dots.innerHTML = '';
      slides.forEach(function (slide, i) {
        slide.setAttribute('role', 'group');
        slide.setAttribute('aria-roledescription', 'slide');
        slide.setAttribute('aria-label', T.slideOf.replace('%1', i + 1).replace('%2', slides.length));
        var li = document.createElement('li');
        li.innerHTML = '<button type="button" class="ww-carousel-dot" aria-label="Banner ' + (i + 1) + '"></button>';
        li.firstChild.addEventListener('click', function () { choose(i); });
        dots.appendChild(li);
      });
      go(current);
      refresh();
    }

    function go(index) {
      if (!slides.length) { return; }
      current = (index + slides.length) % slides.length;
      track.style.transform = 'translateX(' + (-100 * current) + '%)';
      slides.forEach(function (slide, i) {
        var active = i === current;
        slide.setAttribute('aria-hidden', active ? 'false' : 'true');
        // slide tersembunyi tidak bisa difokus dengan Tab
        if (active) { slide.removeAttribute('inert'); } else { slide.setAttribute('inert', ''); }
        var link = slide.querySelector('a');
        if (link) { link.tabIndex = active ? 0 : -1; }
      });
      var dotBtns = dots.querySelectorAll('.ww-carousel-dot');
      for (var d = 0; d < dotBtns.length; d++) {
        dotBtns[d].setAttribute('aria-current', d === current ? 'true' : 'false');
      }
    }

    // pilihan pengunjung: tampilkan slide itu dan hentikan putaran otomatis
    function choose(index) { stopped = true; go(index); refresh(); }

    function stop() { if (timer) { clearInterval(timer); timer = null; } }

    // putar hanya bila tidak ada alasan untuk diam
    function refresh() {
      var running = slides.length > 1 && !stopped && !hovering && !focused && !document.hidden;
      stop();
      if (running) { timer = setInterval(function () { go(current + 1); }, CAROUSEL_DELAY); }
      // pembaca layar diberi tahu pergantian slide hanya saat tidak berputar sendiri
      viewport.setAttribute('aria-live', running ? 'off' : 'polite');
    }

    root.addEventListener('mouseenter', function () { hovering = true; refresh(); });
    root.addEventListener('mouseleave', function () { hovering = false; refresh(); });
    root.addEventListener('focusin', function () { focused = true; refresh(); });
    root.addEventListener('focusout', function (e) {
      if (!root.contains(e.relatedTarget)) { focused = false; refresh(); }
    });
    document.addEventListener('visibilitychange', refresh);

    root.addEventListener('keydown', function (e) {
      if (slides.length < 2) { return; }
      var to = e.key === 'ArrowLeft' ? current - 1 : e.key === 'ArrowRight' ? current + 1 : null;
      if (to === null) { return; }
      choose(to);
      // fokus ikut ke titik slide yang baru bila sedang di deretan titik
      if (dots.contains(document.activeElement)) { dots.querySelectorAll('.ww-carousel-dot')[current].focus(); }
    });

    // geser kiri/kanan di layar sentuh
    var startX = 0, startY = 0;
    viewport.addEventListener('touchstart', function (e) {
      startX = e.touches[0].clientX; startY = e.touches[0].clientY;
    }, { passive: true });
    viewport.addEventListener('touchend', function (e) {
      if (slides.length < 2) { return; }
      var dx = e.changedTouches[0].clientX - startX, dy = e.changedTouches[0].clientY - startY;
      if (Math.abs(dx) > 50 && Math.abs(dx) > Math.abs(dy) * 1.5) { choose(current + (dx < 0 ? 1 : -1)); }
    }, { passive: true });

    // gambar rusak: buang slidenya
    Array.prototype.forEach.call(track.querySelectorAll('img'), function (img) {
      var drop = function () {
        var slide = img.closest('.ww-carousel-slide');
        if (slide && slide.parentNode) { slide.parentNode.removeChild(slide); rebuild(); }
      };
      if (img.complete && img.naturalWidth === 0 && img.getAttribute('src')) { drop(); }
      else { img.addEventListener('error', drop); }
    });

    if (root.parentNode) { rebuild(); }
  }

  /* ------------------------------------------------------------------------
     Lightbox: gambar di isi artikel dibuka sebagai popup saat diketuk.
     - gambar tanpa link              -> popup
     - link ke file gambar (WordPress "link to media file") -> popup, pakai
       gambar dari href (resolusi penuh)
     - link lain (halaman, Play Store, dll.) -> tetap mengikuti link
     ------------------------------------------------------------------------ */
  function largestSrc(img) {
    // ambil kandidat terbesar dari srcset bila ada
    var best = img.currentSrc || img.src, bestW = 0;
    var srcset = img.getAttribute('srcset');
    if (srcset) {
      srcset.split(',').forEach(function (part) {
        var bits = part.trim().split(/\s+/), w = parseInt(bits[1], 10) || 0;
        if (bits[0] && w > bestW) { bestW = w; best = bits[0]; }
      });
    }
    return best;
  }

  function captionOf(img) {
    var fig = img.closest('figure');
    var cap = fig && fig.querySelector('figcaption');
    return (cap && cap.textContent.trim()) || img.getAttribute('alt') || '';
  }

  function initLightbox() {
    // didefinisikan di sini, bukan di level atas: ready() bisa memanggil
    // initLightbox sebelum baris-baris di bawah IIFE dieksekusi
    var IMAGE_URL = /\.(jpe?g|png|gif|webp|avif|bmp|svg)(\?.*)?$/i;
    var items = [];
    var scopes = document.querySelectorAll('.entry-content');
    for (var s = 0; s < scopes.length; s++) {
      var imgs = scopes[s].querySelectorAll('img');
      for (var i = 0; i < imgs.length; i++) {
        var img = imgs[i], link = img.closest('a'), full;
        if (link) {
          var href = link.getAttribute('href') || '';
          if (!IMAGE_URL.test(href)) { continue; } // link sungguhan: biarkan
          full = link.href;
        } else {
          full = largestSrc(img);
        }
        items.push({ img: img, link: link, src: full, caption: captionOf(img) });
      }
    }
    if (!items.length) { return; }

    // markup popup
    var box = document.createElement('div');
    box.className = 'lightbox';
    box.setAttribute('role', 'dialog');
    box.setAttribute('aria-modal', 'true');
    box.setAttribute('aria-label', T.image);
    box.hidden = true;
    box.innerHTML =
      '<button type="button" class="lightbox-close" aria-label="' + T.close + '">&times;</button>' +
      '<button type="button" class="lightbox-nav lightbox-prev" aria-label="' + T.prev + '">&#8249;</button>' +
      '<figure class="lightbox-figure"><img class="lightbox-img" alt=""><figcaption class="lightbox-caption"></figcaption></figure>' +
      '<button type="button" class="lightbox-nav lightbox-next" aria-label="' + T.next + '">&#8250;</button>' +
      '<div class="lightbox-counter" aria-live="polite"></div>';
    document.body.appendChild(box);

    var bigImg = box.querySelector('.lightbox-img');
    var caption = box.querySelector('.lightbox-caption');
    var counter = box.querySelector('.lightbox-counter');
    var btnClose = box.querySelector('.lightbox-close');
    var btnPrev = box.querySelector('.lightbox-prev');
    var btnNext = box.querySelector('.lightbox-next');
    var current = -1, lastFocus = null, multi = items.length > 1;

    if (!multi) { btnPrev.hidden = true; btnNext.hidden = true; }

    function show(index) {
      current = (index + items.length) % items.length;
      var it = items[current];
      box.classList.add('is-loading');
      bigImg.onload = bigImg.onerror = function () { box.classList.remove('is-loading'); };
      bigImg.src = it.src;
      bigImg.alt = it.img.getAttribute('alt') || '';
      caption.textContent = it.caption;
      caption.hidden = !it.caption;
      counter.textContent = multi ? (current + 1) + ' / ' + items.length : '';
    }

    function open(index) {
      lastFocus = document.activeElement;
      show(index);
      box.hidden = false;
      document.body.classList.add('lightbox-open');
      btnClose.focus();
    }

    function close() {
      box.hidden = true;
      bigImg.removeAttribute('src');
      document.body.classList.remove('lightbox-open');
      if (lastFocus && lastFocus.focus) { lastFocus.focus(); }
    }

    items.forEach(function (it, index) {
      var target = it.link || it.img;
      it.img.classList.add('is-zoomable');
      if (!it.link) {
        it.img.setAttribute('tabindex', '0');
        it.img.setAttribute('role', 'button');
      }
      target.addEventListener('click', function (e) { e.preventDefault(); open(index); });
      target.addEventListener('keydown', function (e) {
        if (!it.link && (e.key === 'Enter' || e.key === ' ')) { e.preventDefault(); open(index); }
      });
    });

    btnClose.addEventListener('click', close);
    btnPrev.addEventListener('click', function () { show(current - 1); });
    btnNext.addEventListener('click', function () { show(current + 1); });
    // ketuk area gelap di luar gambar untuk menutup
    box.addEventListener('click', function (e) {
      if (e.target === box || e.target.classList.contains('lightbox-figure')) { close(); }
    });

    document.addEventListener('keydown', function (e) {
      if (box.hidden) { return; }
      if (e.key === 'Escape') { close(); }
      else if (multi && e.key === 'ArrowLeft') { show(current - 1); }
      else if (multi && e.key === 'ArrowRight') { show(current + 1); }
      else if (e.key === 'Tab') {
        // fokus tetap di dalam popup
        var f = [btnClose, btnPrev, btnNext].filter(function (b) { return !b.hidden; });
        var at = f.indexOf(document.activeElement);
        e.preventDefault();
        f[(at + (e.shiftKey ? f.length - 1 : 1)) % f.length].focus();
      }
    });

    // geser kiri/kanan di layar sentuh
    var startX = 0, startY = 0;
    box.addEventListener('touchstart', function (e) {
      startX = e.touches[0].clientX; startY = e.touches[0].clientY;
    }, { passive: true });
    box.addEventListener('touchend', function (e) {
      if (!multi) { return; }
      var dx = e.changedTouches[0].clientX - startX, dy = e.changedTouches[0].clientY - startY;
      if (Math.abs(dx) > 50 && Math.abs(dx) > Math.abs(dy) * 1.5) { show(current + (dx < 0 ? 1 : -1)); }
    }, { passive: true });
  }
})();
