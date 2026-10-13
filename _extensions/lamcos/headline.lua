-- Build a beamer-style headline (section bar) from the document's H1 headings
-- The bar is CLONED INTO EVERY SLIDE <section> so that reveal.js scales it
-- together with the deck (a single after-body copy would stay unscaled and
-- end up misaligned with the gradient/title box outside fullscreen).

local function escape_html(s)
	return (
		s:gsub("[&<>\"']", {
			["&"] = "&amp;",
			["<"] = "&lt;",
			[">"] = "&gt;",
			['"'] = "&quot;",
			["'"] = "&#39;",
		})
	)
end

function Pandoc(doc)
	local sections = {}
	for _, block in ipairs(doc.blocks) do
		if block.t == "Header" and block.level == 1 then
			local id = block.identifier
			local title = pandoc.utils.stringify(block)
			if id ~= "" and title ~= "" then
				table.insert(sections, { id = id, title = title })
			end
		end
	end

	if #sections == 0 then
		return nil
	end

	-- The static nav markup (one copy, used as a template)
	local nav = '<nav class="headline">\n'
	for _, s in ipairs(sections) do
		nav = nav .. string.format('  <a href="#/%s" data-section="%s">%s</a>\n', s.id, s.id, escape_html(s.title))
	end
	nav = nav .. "</nav>\n"

	-- Script: move the template INTO each slide section on load, so it
	-- lives inside reveal's scaled coordinate system, then highlight the
	-- current section on every slide change.
	nav = nav
		.. [[
    <script>
      (function () {
        var template = null;

        function lamcosInjectHeadline() {
          template = document.querySelector("nav.headline");
          if (!template) return;
          template.parentElement.removeChild(template); // take it out of <body>
          document.querySelectorAll(".reveal .slides section").forEach(function (sec) {
            var clone = template.cloneNode(true);
            sec.insertBefore(clone, sec.firstChild);
          });
        }

        function lamcosUpdateHeadline(current) {
          if (!current) current = (typeof Reveal !== "undefined") ? Reveal.getCurrentSlide() : null;
          if (!current) return;
          var slides = document.querySelectorAll(".reveal section");
          var ids = Array.from(document.querySelectorAll(".headline a"))
                          .map(function (a) { return a.dataset.section; });
          var active = null;
          var idx = Array.from(slides).indexOf(current);
          for (var i = idx; i >= 0; i--) {
            var id = slides[i].getAttribute("id");
            if (id && ids.indexOf(id) >= 0) { active = id; break; }
          }
          document.querySelectorAll(".headline a").forEach(function (a) {
            a.classList.toggle("current", a.dataset.section === active);
          });
        }

        window.addEventListener("load", function () {
          lamcosInjectHeadline();
          lamcosUpdateHeadline();
        });
        document.addEventListener("slidechanged", function (ev) {
          lamcosUpdateHeadline(ev.currentSlide);
        });
      })();
    </script>
  ]]

	quarto.doc.include_text("after-body", nav)
	return doc
end
