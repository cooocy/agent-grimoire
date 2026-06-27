#!/usr/bin/env fish

set SCRIPT_DIR (dirname (status --current-filename))
set SOURCE_SKILLS (realpath "$SCRIPT_DIR/skills")

function next_backup_path --argument-names original_path
    set base "$original_path"_(date +%Y%m%d-%H%M%S)_$fish_pid
    set candidate "$base"
    set sequence 1

    while test -e "$candidate"; or test -L "$candidate"
        set candidate "$base"_$sequence
        set sequence (math $sequence + 1)
    end

    echo "$candidate"
end

if not test -d "$SOURCE_SKILLS"
    echo "Source skills directory not found: $SOURCE_SKILLS"
    exit 1
end

set TARGET_SKILL_DIRS \
    ~/.claude/skills \
    ~/.codex/skills \
    ~/.config/opencode/skills

for target_dir in $TARGET_SKILL_DIRS
    if not mkdir -p (dirname "$target_dir")
        echo "Failed to create parent directory for: $target_dir" >&2
        exit 1
    end

    # 如果目标 skills 本身已经是软链，说明是旧脚本创建的，需要先拆掉
    if test -L "$target_dir"
        set old_target (realpath "$target_dir" 2>/dev/null)

        if not rm "$target_dir"
            echo "Failed to remove old symlink: $target_dir" >&2
            exit 1
        end

        if not mkdir -p "$target_dir"
            echo "Failed to recreate target directory: $target_dir" >&2
            exit 1
        end

        echo "Recreated target directory: $target_dir"
        echo "Old symlink target was: $old_target"
    else if test -e "$target_dir"; and not test -d "$target_dir"
        set backup (next_backup_path "$target_dir")
        if not mv "$target_dir" "$backup"
            echo "Failed to back up $target_dir to $backup" >&2
            exit 1
        end

        if not mkdir -p "$target_dir"
            echo "Failed to create target directory: $target_dir" >&2
            exit 1
        end

        echo "Backed up non-directory $target_dir to $backup"
    else
        if not mkdir -p "$target_dir"
            echo "Failed to create target directory: $target_dir" >&2
            exit 1
        end
    end

    for skill_path in $SOURCE_SKILLS/*
        if not test -d "$skill_path"
            continue
        end

        set skill_name (basename "$skill_path")

        # 跳过隐藏目录，比如 .system、.cache 之类
        if string match -q ".*" "$skill_name"
            continue
        end

        set link_path "$target_dir/$skill_name"

        if test -L "$link_path"
            set current_target (realpath "$link_path" 2>/dev/null)

            if test "$current_target" = "$skill_path"
                echo "Already linked: $link_path -> $skill_path"
                continue
            end
        end

        if test -e "$link_path"; or test -L "$link_path"
            set backup (next_backup_path "$link_path")
            if not mv "$link_path" "$backup"
                echo "Failed to back up $link_path to $backup" >&2
                exit 1
            end
            echo "Backed up existing $link_path to $backup"
        end

        if not ln -s "$skill_path" "$link_path"
            echo "Failed to link $link_path to $skill_path" >&2
            exit 1
        end
        echo "Linked $link_path -> $skill_path"
    end
end
