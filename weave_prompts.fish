#!/usr/bin/env fish

function usage
    echo "Usage: ./weave_prompts.fish <target-directory> <prompt-name> [prompt-name ...]" >&2
    echo "Example: ./weave_prompts.fish ~/Downloads common_conventions java_convention" >&2
end

if test (count $argv) -lt 2
    usage
    exit 2
end

set target_dir (string replace -r '/+$' '' -- $argv[1])
if test -z "$target_dir"
    set target_dir /
end

if not test -d "$target_dir"
    echo "Target directory does not exist: $target_dir" >&2
    exit 1
end

set script_dir (realpath (dirname (status --current-filename)))
set prompts_dir "$script_dir/prompts"
set prompt_names $argv[2..-1]
set prompt_paths

for prompt_name in $prompt_names
    set prompt_path "$prompts_dir/$prompt_name.md"
    if not test -f "$prompt_path"
        echo "Prompt not found: $prompt_path" >&2
        exit 1
    end
    set -a prompt_paths "$prompt_path"
end

set merged_file (mktemp "$target_dir/.weave-prompts-merged.XXXXXX")
or begin
    echo "Failed to create a temporary file in: $target_dir" >&2
    exit 1
end

set agents_file (mktemp "$target_dir/.weave-prompts-agents.XXXXXX")
or begin
    rm -f "$merged_file"
    echo "Failed to create a temporary file in: $target_dir" >&2
    exit 1
end

set claude_file (mktemp "$target_dir/.weave-prompts-claude.XXXXXX")
or begin
    rm -f "$merged_file" "$agents_file"
    echo "Failed to create a temporary file in: $target_dir" >&2
    exit 1
end

function cleanup --on-event fish_exit
    rm -f "$merged_file" "$agents_file" "$claude_file"
end

for index in (seq (count $prompt_paths))
    cat "$prompt_paths[$index]" >>"$merged_file"
    or begin
        echo "Failed to read prompt: $prompt_paths[$index]" >&2
        exit 1
    end

    if test "$index" -lt (count $prompt_paths)
        printf '\n' >>"$merged_file"
    end
end

cp "$merged_file" "$agents_file"
and cp "$merged_file" "$claude_file"
or begin
    echo "Failed to prepare generated files in: $target_dir" >&2
    exit 1
end

mv -f "$agents_file" "$target_dir/AGENTS.md"
or begin
    echo "Failed to write: $target_dir/AGENTS.md" >&2
    exit 1
end

mv -f "$claude_file" "$target_dir/CLAUDE.md"
or begin
    echo "Failed to write: $target_dir/CLAUDE.md" >&2
    exit 1
end

echo "Generated: $target_dir/AGENTS.md"
echo "Generated: $target_dir/CLAUDE.md"
