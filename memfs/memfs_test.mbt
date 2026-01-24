// Tests for MemFS

test "create and read file" {
  let fs = MemFS::new()
  fs.write_string("/test.txt", "Hello, World!")
  assert_eq(fs.read_string("/test.txt"), "Hello, World!")
}

test "mkdir and list" {
  let fs = MemFS::new()
  fs.mkdir("/dir")
  fs.write_string("/dir/file.txt", "content")

  let entries = fs.readdir("/dir")
  assert_eq(entries.length(), 1)
  assert_eq(entries[0], "file.txt")
}

test "mkdir_p creates nested dirs" {
  let fs = MemFS::new()
  fs.mkdir_p("/a/b/c")

  assert_true(fs.is_dir("/a"))
  assert_true(fs.is_dir("/a/b"))
  assert_true(fs.is_dir("/a/b/c"))
}

test "symlink" {
  let fs = MemFS::new()
  fs.write_string("/target.txt", "target content")
  fs.symlink("/link.txt", "target.txt")

  assert_true(fs.is_symlink("/link.txt"))
  assert_eq(fs.read_string("/link.txt"), "target content")
}

test "absolute symlink" {
  let fs = MemFS::new()
  fs.mkdir("/dir")
  fs.write_string("/dir/file.txt", "content")
  fs.symlink("/link", "/dir/file.txt")

  assert_eq(fs.read_string("/link"), "content")
}

test "remove file" {
  let fs = MemFS::new()
  fs.write_string("/test.txt", "content")
  assert_true(fs.exists("/test.txt"))

  fs.remove("/test.txt")
  assert_false(fs.exists("/test.txt"))
}

test "rmdir" {
  let fs = MemFS::new()
  fs.mkdir("/empty_dir")
  assert_true(fs.is_dir("/empty_dir"))

  fs.rmdir("/empty_dir")
  assert_false(fs.exists("/empty_dir"))
}

test "file size" {
  let fs = MemFS::new()
  fs.write_string("/test.txt", "12345")

  assert_eq(fs.size("/test.txt"), Some(5))
}

test "is_file and is_dir" {
  let fs = MemFS::new()
  fs.mkdir("/dir")
  fs.write_string("/file.txt", "content")

  assert_true(fs.is_dir("/dir"))
  assert_false(fs.is_file("/dir"))

  assert_true(fs.is_file("/file.txt"))
  assert_false(fs.is_dir("/file.txt"))
}

test "exists" {
  let fs = MemFS::new()
  fs.write_string("/exists.txt", "")

  assert_true(fs.exists("/exists.txt"))
  assert_false(fs.exists("/not_exists.txt"))
}

test "readdir on root" {
  let fs = MemFS::new()
  fs.mkdir("/dir1")
  fs.mkdir("/dir2")
  fs.write_string("/file.txt", "")

  let entries = fs.readdir("/")
  assert_eq(entries.length(), 3)
}

test "default creates standard dirs" {
  let fs = MemFS::default()

  assert_true(fs.is_dir("/bin"))
  assert_true(fs.is_dir("/home"))
  assert_true(fs.is_dir("/tmp"))
}

test "path normalization with dots" {
  let fs = MemFS::new()
  fs.mkdir("/a")
  fs.mkdir("/a/b")
  fs.write_string("/a/b/file.txt", "content")

  // These should all work
  assert_eq(fs.read_string("/a/./b/file.txt"), "content")
  assert_eq(fs.read_string("/a/b/../b/file.txt"), "content")
}

test "overwrite file" {
  let fs = MemFS::new()
  fs.write_string("/test.txt", "first")
  fs.write_string("/test.txt", "second")

  assert_eq(fs.read_string("/test.txt"), "second")
}

test "total size tracking" {
  let fs = MemFS::new()
  fs.write_string("/a.txt", "12345")
  fs.write_string("/b.txt", "123")

  assert_eq(fs.total_size(), 8)

  fs.remove("/a.txt")
  assert_eq(fs.total_size(), 3)
}

test "file count" {
  let fs = MemFS::new()
  fs.mkdir("/dir")
  fs.write_string("/a.txt", "")
  fs.write_string("/b.txt", "")

  assert_eq(fs.file_count(), 2)
}
