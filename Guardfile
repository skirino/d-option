guard :shell, all_on_start: true do
  watch(/^source\/.*\.d$/) { |_| puts `dub test` }
end
