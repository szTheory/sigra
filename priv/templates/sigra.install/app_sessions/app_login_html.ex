defmodule <%= web_module %>.AppLoginHTML do
  use <%= web_module %>, :html
  import <%= web_module %>.SigraAuthComponents

  embed_templates "app_login_html/*"
end
