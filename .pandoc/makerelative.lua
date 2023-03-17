function Image (img)
  img.src = pandoc.path.make_relative(img.src, '/')
  return img
end

