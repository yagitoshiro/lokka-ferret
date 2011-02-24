require 'ferret'
require 'default_parser'
require 'dm-migrations'

module Lokka
  module Ferret
     def self.registered(app)
      app.before do
        ferret_init
        method = request.env['REQUEST_METHOD']
        if @ferret_index_dir && (method == 'PUT' || method == 'POST')
          case 
          when request.env['PATH_INFO'] =~ /\/admin\/(posts|pages)(\/[\d]+\/edit)?/
            ferret = @ferret
            Entry.after :save do; ferret_index(ferret); end
          end
        end
      end

      # All your /search/ is belong to us
      app.get '/search/' do
        ferret_init
        limit = settings.per_page
        @theme_types << :search
        @theme_types << :entries

        if !params[:query].blank? && @ferret_index_dir
          @query = params[:query]
          q = '*:' + @ferret.parse(@query)

          @posts = []
          ids = []

          repo_data = repository(:search).search(q).to_a
          unless repo_data.blank?
            ids = repo_data[0][1].map{|id| id.to_i}
          end
          @posts = Entry.all(:id => ids).
                      page(params[:page], :per_page => settings.per_page)
          # stupid sort ordering
          page = params[:page] ? params[:page] : 1
          if page > 1
            offset = (page - 1) * limit + 1
          else
            offset = 0
          end
          tmp_post_hash = {}
          @posts.each do |post|
            tmp_post_hash[post.id] = post
          end
          ids.slice(offset, setting.per_page).each_with_index do |post, id|
            @posts[id] = tmp_post_hash[post]
          end
        else
          @query = params[:query]
          @posts = Post.search(@query).
                      page(params[:page], :per_page => settings.per_page)
        end

        @title = "Search by #{@query} - #{@site.title}"

        @bread_crumbs = BreadCrumb.new
        @bread_crumbs.add(t.home, '/')
        @bread_crumbs.add(@query)

        render_detect :search, :entries
      end

      # admin panel
      app.get '/admin/plugins/ferret' do
        login_required
        ferret_init
        haml :"#{ferret_view}index", :layout => :"admin/layout"
      end

      app.put '/admin/plugins/ferret' do
        login_required
        ferret_init
        save = params[:ferret]
        if save['ferret_parse_method'] != 'yahoo'
          save['ferret_yahoo_id'] = ''
        end
        begin
          ::Ferret::Index::Index.new(:path => save['ferret_index_dir'])
          if save['ferret_parse_method'] == 'yahoo' && save['ferret_yahoo_id'] == ''
            raise
          end
          Option.ferret_index_dir = save['ferret_index_dir']
          Option.ferret_parse_method = save['ferret_parse_method']
          Option.ferret_yahoo_id = save['ferret_yahoo_id']
        rescue
          flash[:notice] = t.ferret.index_dir_db_error
          haml :"#{ferret_view}index", :layout => :"admin/layout"
        else
          flash[:notice] = t.ferret.index_dir_updated
          redirect '/admin/plugins/ferret'
        end
      end
    end
  end
  module Helpers
    def ferret_view
      "plugin/lokka-ferret/views/"
    end

    def ferret_init
      @ferret_index_dir = Option.ferret_index_dir unless @ferret_index_dir
      @ferret_parse_method = Option.ferret_parse_method unless @ferret_parse_method
      @ferret_yahoo_id = Option.ferret_yahoo_id unless @ferret_yahoo_id
      unless @ferret
        if @ferret_index_dir && @ferret_parse_method
          require "#{@ferret_parse_method}_parser"
          @ferret = ::Lokka.const_get("#{@ferret_parse_method.camelize}_Parser").new(@ferret_yahoo_id)
          ::DataMapper.setup(:search, {:term_vector => :yes, :adapter => :ferret, :path => @ferret_index_dir, :analyzer => ::Ferret::Analysis::WhiteSpaceAnalyzer.new, :auto_flush => true, :locale => 'ja_JP.UTF-8'})
          require 'entry_ferret'
        end
      end
      unless @ferret_methods
        @ferret_methods = []
        @ferret_methods.push(['default', '--'])
        @ferret_methods.push(['mecab', 'MeCab'])
        @ferret_methods.push(['yahoo', 'Yahoo! API'])
      end
    end
  end
end

