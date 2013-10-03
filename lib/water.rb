require 'fileutils'
require 'pathname'

require 'coderay'
require 'launchy'

class Water
  DIFF_DIR_NAME  = Pathname.new('~/.water').expand_path
  
  CSS = <<-CSS
body {
  background: gray;
  padding-bottom: 1000px;
}
body > a {
  display: block;
  position: fixed;
  top: 0;
  right: 0;
  background: gray;
  color: white;
  padding: 5px 10px;
  font-family: monospace;
  font-weight: bold;
  text-decoration: none;
}
body > a:hover {
  text-decoration: underline;
}

.diff-block {
  background: hsl(0,0%,95%);
  margin: 5px;
  margin-bottom: 0;
  padding: 3px 6px;
  overflow-y: visible;
  overflow-x: auto;
  -webkit-transition: 0.3s;
     -moz-transition: 0.3s;
          transition: 0.3s;
}
.diff-block.closed {
  margin-top: -5px;
  overflow: hidden;
}
.diff-block:first-of-type.closed {
  margin-top: 0;
}

.CodeRay pre {
  width: -moz-fit-content;
  line-height: 15px;
}
.CodeRay .line {
  float: none;
  height: 15px;
}
.diff-block-content .CodeRay .line {
  margin-bottom: -15px;
}
  CSS
  
  def self.run
    new.run
  end
  
  def run
    diff = ARGF.read
    
    if diff.chomp.empty?
      puts 'Your diff is empty.'
    else
      DIFF_DIR_NAME.mkpath
      open_diff_file write_diff_file(diff)
    end
  end
  
  def get_file_path
    home = Pathname.new('~').expand_path
    pwd  = Pathname.pwd
    relative_path = pwd.relative_path_from(home)
    
    name = relative_path.to_s.gsub('../', '').gsub('/', '-')
    name << '.diff.html'
    
    DIFF_DIR_NAME + name
  end
  
  def write_diff_file diff
    file_path = get_file_path
    
    File.open file_path, 'w' do |file|
      file.write water(diff)
    end
    
    file_path
  end
  
  def water diff
    output = diff.gsub(/\r\n?/, "\n").scan(/ (?> ^(?!-(?!--\ )|\+(?!\+\+)|[\\ ]|$|@@) .*\n)* (?> ^(?=-(?!--\ )|\+(?!\+\+)|[\\ ]|$|@@) .*(?:\n|\z))+ /x).map do |block|
      head_ray, content_ray = CodeRay.scanner(:diff).tokenize(block.split("\n", 2))
      content_ray ||= ''
      
      <<-HTML % [head_ray.div(:css => :class), content_ray.div(:css => :class)]
<div class="diff-block">
  <div class="diff-block-head">%s</div>
  <div class="diff-block-content">%s</div>
</div>
      HTML
    end.join("\n")
    
    output.extend(CodeRay::Encoders::HTML::Output)
    output.css = CodeRay::Encoders::HTML::CSS.new(:alpha)
    
    if output.css.respond_to? :css
      def (output.css).css
        super + Water::CSS
      end
    else
      output.css.stylesheet << Water::CSS
    end
    
    output.wrap_in! CodeRay::Encoders::HTML::Output.page_template_for_css(output.css)
    output.apply_title! "diff #{Dir.pwd} | water"
    
    output[/<\/head>\s*<body[^>]*>?/] = <<-JS
    <script src="https://ajax.googleapis.com/ajax/libs/jquery/1.7.1/jquery.min.js"></script>
    <script>
      $(function () {
        $('.diff-block').live('click', function () {
          $(this).toggleClass('closed').find('.diff-block-content').slideToggle('fast');
          $('html, body').animate({ scrollTop: $(this).offset().top }, 'fast');
        });
        $('.diff-block').live('touchend', function () {
          $(this).toggleClass('closed').find('.diff-block-content').slideToggle('fast');
          $('html, body').animate({ scrollTop: $(this).offset().top }, 'fast');
        });
        $('a.toggle-all').click(function () {
          $('.diff-block').toggleClass('closed').find('.diff-block-content').toggle();
        });
      })
    </script>
    </head>
    
    <body>
      <a href="#" class="toggle-all">toggle all</a>
    JS
    
    output
  end
  
  def open_diff_file file_path
    Launchy.open "file://#{file_path.expand_path}"
  end
end