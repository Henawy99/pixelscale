/* =================================================================
   Moving Company Salzburg – script.js
   Handles: Navbar scroll, mobile menu, hero particles, scroll reveal,
   counter animation, scroll-to-top, smooth scrolling, form handling
   ================================================================= */

'use strict';

/* ----------------------------------------------------------------
   NAVBAR: scroll effect + mobile hamburger
   ---------------------------------------------------------------- */
const navbar = document.getElementById('navbar');
const hamburger = document.getElementById('hamburger');
const navLinks = document.getElementById('navLinks');

window.addEventListener('scroll', () => {
  if (window.scrollY > 60) {
    navbar.classList.add('scrolled');
  } else {
    navbar.classList.remove('scrolled');
  }
}, { passive: true });

hamburger.addEventListener('click', () => {
  const isOpen = navLinks.classList.toggle('open');
  hamburger.classList.toggle('open', isOpen);
  hamburger.setAttribute('aria-expanded', isOpen);
});

// Close mobile menu when a link is clicked
navLinks.querySelectorAll('a').forEach(link => {
  link.addEventListener('click', () => {
    navLinks.classList.remove('open');
    hamburger.classList.remove('open');
    hamburger.setAttribute('aria-expanded', 'false');
  });
});

/* Particles removed for cleaner design */

/* ----------------------------------------------------------------
   SCROLL REVEAL
   ---------------------------------------------------------------- */
function initScrollReveal() {
  const revealEls = document.querySelectorAll(
    '.service-card, .why-card, .testimonial-card, .about-card, .trust-badge, .stat-item, .contact-item'
  );
  revealEls.forEach(el => el.classList.add('reveal'));

  const observer = new IntersectionObserver((entries) => {
    entries.forEach((entry, i) => {
      if (entry.isIntersecting) {
        // stagger siblings
        const siblings = Array.from(entry.target.parentElement.querySelectorAll('.reveal'));
        const idx = siblings.indexOf(entry.target);
        setTimeout(() => {
          entry.target.classList.add('revealed');
        }, idx * 80);
        observer.unobserve(entry.target);
      }
    });
  }, { threshold: 0.12, rootMargin: '0px 0px -60px 0px' });

  revealEls.forEach(el => observer.observe(el));
}
initScrollReveal();

/* ----------------------------------------------------------------
   COUNTER ANIMATION
   ---------------------------------------------------------------- */
function animateCounters() {
  const counters = document.querySelectorAll('.counter');
  if (!counters.length) return;

  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        const el = entry.target;
        const target = parseInt(el.dataset.target, 10);
        const duration = 1800;
        const step = target / (duration / 16);
        let current = 0;

        const timer = setInterval(() => {
          current += step;
          if (current >= target) {
            current = target;
            clearInterval(timer);
          }
          el.textContent = Math.floor(current);
        }, 16);

        observer.unobserve(el);
      }
    });
  }, { threshold: 0.5 });

  counters.forEach(c => observer.observe(c));
}
animateCounters();

/* ----------------------------------------------------------------
   SCROLL-TO-TOP
   ---------------------------------------------------------------- */
const scrollTopBtn = document.getElementById('scrollTop');

window.addEventListener('scroll', () => {
  if (window.scrollY > 500) {
    scrollTopBtn.classList.add('visible');
  } else {
    scrollTopBtn.classList.remove('visible');
  }
}, { passive: true });

scrollTopBtn.addEventListener('click', () => {
  window.scrollTo({ top: 0, behavior: 'smooth' });
});

/* ----------------------------------------------------------------
   SMOOTH SCROLL for anchor links
   ---------------------------------------------------------------- */
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
  anchor.addEventListener('click', function (e) {
    const href = this.getAttribute('href');
    if (href === '#') return;
    const target = document.querySelector(href);
    if (target) {
      e.preventDefault();
      const offset = 80;
      const top = target.getBoundingClientRect().top + window.scrollY - offset;
      window.scrollTo({ top, behavior: 'smooth' });
    }
  });
});

/* ----------------------------------------------------------------
   ACTIVE NAV LINK on scroll
   ---------------------------------------------------------------- */
const sections = document.querySelectorAll('section[id]');
const navItems = document.querySelectorAll('.nav-links a[href^="#"]');

function updateActiveNav() {
  const scrollY = window.scrollY + 100;
  sections.forEach(section => {
    const top = section.offsetTop;
    const bottom = top + section.offsetHeight;
    const id = section.getAttribute('id');
    const link = document.querySelector(`.nav-links a[href="#${id}"]`);
    if (link) {
      if (scrollY >= top && scrollY < bottom) {
        navItems.forEach(l => l.style.color = '');
        link.style.color = 'var(--clr-white)';
      }
    }
  });
}
window.addEventListener('scroll', updateActiveNav, { passive: true });

/* ----------------------------------------------------------------
   FOOTER YEAR
   ---------------------------------------------------------------- */
const yearEl = document.getElementById('year');
if (yearEl) yearEl.textContent = new Date().getFullYear();

/* ----------------------------------------------------------------
   FORM HANDLING (formsubmit.co – redirect after success)
   We enhance the form to show a success state without page reload.
   ---------------------------------------------------------------- */
const form = document.getElementById('contactForm');

if (form) {
  form.addEventListener('submit', function (e) {
    // Basic validation
    const nameEl = document.getElementById('name');
    const emailEl = document.getElementById('email');
    const fromEl = document.getElementById('fromAddress');
    const toEl = document.getElementById('toAddress');
    const consentEl = document.getElementById('consent');

    let valid = true;
    [nameEl, emailEl, fromEl, toEl].forEach(el => {
      el.style.borderColor = '';
      if (!el.value.trim()) {
        el.style.borderColor = '#ef4444';
        valid = false;
      }
    });
    if (!consentEl.checked) {
      consentEl.parentElement.style.color = '#ef4444';
      valid = false;
    } else {
      consentEl.parentElement.style.color = '';
    }
    if (!valid) {
      e.preventDefault();
      const status = document.getElementById('formStatus');
      if (status) {
        status.className = 'form-status error';
        status.textContent = 'Bitte füllen Sie alle Pflichtfelder aus.';
      }
    }
    // If valid, form submits normally to formsubmit.co
  });

  // Restore field styles on input
  form.querySelectorAll('input, textarea').forEach(el => {
    el.addEventListener('input', () => {
      el.style.borderColor = '';
      const status = document.getElementById('formStatus');
      if (status && status.classList.contains('error')) {
        status.className = 'form-status';
        status.textContent = '';
      }
    });
  });
}

/* ----------------------------------------------------------------
   SERVICE CARDS – hover micro-animation for icons
   ---------------------------------------------------------------- */
document.querySelectorAll('.service-card').forEach(card => {
  card.addEventListener('mouseenter', () => {
    const icon = card.querySelector('.service-icon');
    if (icon) icon.style.transform = 'scale(1.12) rotate(-3deg)';
  });
  card.addEventListener('mouseleave', () => {
    const icon = card.querySelector('.service-icon');
    if (icon) icon.style.transform = '';
  });
});

/* ----------------------------------------------------------------
   WHY CARDS – staggered entrance
   ---------------------------------------------------------------- */
const whyCards = document.querySelectorAll('.why-card');
const whyObserver = new IntersectionObserver((entries) => {
  entries.forEach(entry => {
    if (entry.isIntersecting) {
      const cards = document.querySelectorAll('.why-card');
      cards.forEach((card, i) => {
        setTimeout(() => {
          card.style.opacity = '1';
          card.style.transform = 'translateY(0)';
        }, i * 100);
      });
      whyObserver.disconnect();
    }
  });
}, { threshold: 0.15 });

whyCards.forEach(card => {
  card.style.opacity = '0';
  card.style.transform = 'translateY(30px)';
  card.style.transition = 'opacity 0.6s ease, transform 0.6s ease, border-color 0.3s ease';
});
if (whyCards.length) whyObserver.observe(whyCards[0]);
