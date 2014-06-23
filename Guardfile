guard :shell, all_on_start: true do
  watch(/^source\/(?!\.#)(?!.*_flymake).*\.d$/) do |_|
    puts `dub test`
  end
end
