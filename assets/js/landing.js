(function () {
  var links = document.querySelectorAll('.tl-page a[href^="#"]');
  links.forEach(function (link) {
    link.addEventListener('click', function (event) {
      var targetId = link.getAttribute('href');
      var target = targetId ? document.querySelector(targetId) : null;
      if (!target) return;
      event.preventDefault();
      target.scrollIntoView({ behavior: 'smooth', block: 'start' });
    });
  });
})();
