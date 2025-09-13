# refactored web package

this package reorganizes the original inline scripts/css into helper modules and page-specific modules while preserving behavior.

## structure
- assets/css/style.css  — original shared styles
- assets/css/projects.css — projects page styles moved from <style> tag
- assets/js/helpers/nav.js — shared nav toggle + footer year
- assets/js/projects/data.js — projects config (tabs, assets, charts)
- assets/js/projects/viewer.js — pdf/svg/image viewer helpers
- assets/js/projects/ui.js — tabs + project switching
- assets/js/projects/main.js — page bootstrap
- legacy/app.hub.js — original app.js (minus viewer iife)
- assets/js/viewer.legacy.js — viewer iife from app.js (for reference)

## pages
- index.html uses style.css + nav.js
- projects.html now links projects.css + nav.js and loads es modules for the viewer
- domguardianai.html uses style.css + nav.js

## smoke test
open projects.html locally; click tree items to switch projects; tabs should populate and the default project is 'dgai'. the svg/pdf viewer renders via pdfjs or inline svg.

