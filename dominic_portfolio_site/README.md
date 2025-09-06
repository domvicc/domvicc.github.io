# dominic portfolio — github pages

this is a clean, modern multi‑page portfolio template designed for github pages. pages included:

- `index.html` (home)
- `projects.html`
- `domguardianai.html`

## quick start

1. create a repo named `username.github.io` on github (replace `username`).
2. clone the repo locally and copy this folder's contents into it.
3. commit and push:  
   - `git add .`  
   - `git commit -m "init portfolio"`  
   - `git push`
4. in the repo: settings → pages → source: `deploy from branch`, branch: `main`, folder: `/ (root)`.
5. open `https://username.github.io` to see your site live.

## editing with vs code

- open the folder in vs code, and edit the `.html` files.
- global styles are in `assets/css/style.css`.
- basic scripts (mobile nav) are in `assets/js/main.js`.

## adding images and other files

- place images in `assets/img/` (project screenshots under `assets/img/projects/`).
- update the `src` attribute in the html where indicated by comments.
- always add `alt` text for accessibility.
- keep filenames simple: `kebab-case-like-this.jpg`.

example:

```html
<!-- projects.html -->
<img src="assets/img/projects/minwage.jpg" alt="minimum wage dashboard screenshot" class="project-image">
```

## customizing the header and details

- the large header on the home page is the `<h1 class="hero-title">` element — update it with your name.
- update contact links in the footer across pages.
- duplicate `.project-card` blocks in `projects.html` for more projects.

## custom domain (optional)

- buy a domain (namecheap, cloudflare, etc.).
- in repo settings → pages, add your domain (this creates a `cname` file).
- set a `cname` record at your registrar to `username.github.io`.
- github will provision https automatically.

## license

you own your content. do whatever you want with this template.
