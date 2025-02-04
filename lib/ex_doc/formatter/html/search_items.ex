defmodule ExDoc.Formatter.HTML.SearchItems do
  @moduledoc false

  # TODO: It should not depend on the parent module
  alias ExDoc.Formatter.HTML

  def create(nodes, extras) do
    items = Enum.flat_map(nodes, &module/1) ++ Enum.flat_map(extras, &extra/1)
    ["searchNodes=" | ExDoc.Utils.to_json(items)]
  end

  defp extra(map) do
    {intro, sections} = extract_sections_from_markdown(map.source)

    intro_json_item =
      encode(
        "#{map.id}.html",
        map.title,
        :extras,
        intro
      )

    section_json_items =
      for {header, body} <- sections do
        encode(
          "#{map.id}.html##{HTML.text_to_id(header)}",
          header <> " - #{map.title}",
          :extras,
          body
        )
      end

    [intro_json_item | section_json_items]
  end

  defp module(%ExDoc.ModuleNode{} = node) do
    {intro, sections} = extract_sections(node.doc_format, node)

    module =
      encode(
        "#{node.id}.html",
        node.id,
        node.type,
        intro
      )

    module_sections =
      for {header, body} <- sections do
        encode(
          "#{node.id}.html#module-#{HTML.text_to_id(header)}",
          header <> " - #{node.title}",
          node.type,
          body
        )
      end

    functions = Enum.flat_map(node.docs, &node_child(&1, node))
    types = Enum.flat_map(node.typespecs, &node_child(&1, node))
    [module] ++ module_sections ++ functions ++ types
  end

  defp node_child(node, module_node) do
    {intro, sections} = extract_sections(module_node.doc_format, node)

    child =
      encode(
        "#{module_node.id}.html##{node.id}",
        "#{module_node.id}.#{node.name}/#{node.arity}",
        node.type,
        intro
      )

    child_sections =
      for {header, body} <- sections do
        encode(
          "#{module_node.id}.html##{node.id}-#{HTML.text_to_id(header)}",
          header <> " - #{module_node.id}.#{node.name}/#{node.arity}",
          node.type,
          body
        )
      end

    [child] ++ child_sections
  end

  defp encode(ref, title, type, doc) do
    %{
      ref: URI.encode(ref),
      title: title,
      type: type,
      doc: doc
    }
  end

  defp extract_sections("text/markdown", %{source_doc: %{"en" => doc}}) do
    extract_sections_from_markdown(doc)
  end

  defp extract_sections("application/erlang+html", %{rendered_doc: doc}) do
    {clean_html(doc), []}
  end

  defp extract_sections(_format, _doc) do
    {"", []}
  end

  defp extract_sections_from_markdown(string) do
    [intro | sections] = Regex.split(~r/## (?<header>\b.+)/, string, include_captures: true)

    sections =
      for [header, section] <- Enum.chunk_every(sections, 2) do
        "## " <> header = header

        section =
          section
          |> HTML.strip_tags(" ")
          |> String.trim()

        {clean_markdown(header), section}
      end

    {clean_markdown(intro), sections}
  end

  defp clean_markdown(doc) do
    doc
    |> HTML.strip_tags(" ")
    |> String.trim()
  end

  defp clean_html(doc) do
    doc
    |> HTML.strip_tags(" ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end
end
