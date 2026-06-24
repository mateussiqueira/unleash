(function () {
  var searchInput = document.getElementById("search-input");
  var searchResults = document.getElementById("search-results");
  if (!searchInput) return;

  var searchData = [];

  fetch("/search.json")
    .then(function (r) { return r.json(); })
    .then(function (data) { searchData = data; })
    .catch(function () {});

  searchInput.addEventListener("input", function () {
    var query = searchInput.value.trim().toLowerCase();
    if (query.length < 2) {
      searchResults.innerHTML = "";
      searchResults.style.display = "none";
      return;
    }

    var results = searchData.filter(function (item) {
      return item.title.toLowerCase().indexOf(query) !== -1 ||
             item.content.toLowerCase().indexOf(query) !== -1;
    }).slice(0, 10);

    if (results.length === 0) {
      searchResults.innerHTML = '<div class="search-result-item">No results found</div>';
    } else {
      var html = "";
      results.forEach(function (item) {
        var idx = item.content.toLowerCase().indexOf(query);
        var snippet = idx === -1
          ? item.content.slice(0, 120)
          : "…" + item.content.slice(Math.max(0, idx - 40), idx + 80) + "…";
        html += '<a href="' + item.url + '" class="search-result-item">' +
                '<strong>' + item.title + '</strong>' +
                '<span class="search-snippet">' + snippet + '</span>' +
                '</a>';
      });
      searchResults.innerHTML = html;
    }
    searchResults.style.display = "block";
  });

  document.addEventListener("click", function (e) {
    if (!searchInput.contains(e.target) && !searchResults.contains(e.target)) {
      searchResults.style.display = "none";
    }
  });
})();
