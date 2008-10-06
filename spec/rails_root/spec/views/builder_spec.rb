require File.dirname(__FILE__) + '/../spec_helper'

describe 'builder' do

  def article
    @article ||= Article.new( :title => 'first', :body => 'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.', :published => true)
  end
  
  before(:each) do
    assigns[:article] = article
    article.valid?
    render :partial => 'article/show_default'
  end
  
  describe 'rendering an object with no errors' do
    it 'should render default' do
      match_default
    end
  end
  
  
  describe 'rendering an object with errors' do
    def article
      super.title = nil # make the article invalid
      super
    end
    
    it 'should indicate errors' do
      match_default_with_error
    end
  end
  
  protected
  def match_default_with_error
    response.should have_tag('form') do
      with_tag('p[class*=text][class*=error]') do
        with_tag( 'label[for=article_title]', "Title: (required) Can't be blank.")
        with_tag( 'input[id=article_title][type=text]')
      end
      with_tag('div[class*=buttons]') do
        with_tag('button[type=submit][class*=positive]') do
          with_tag('img[src=/images/icons/tick.png]')
        end
        with_tag('a') do
          with_tag('img[src=/images/icons/arrow_undo.png]')
        end
      end
    end
  end
  
  def match_default
    response.should have_tag('form') do
      with_tag('p[class*=text]') do
        with_tag( 'label[for=article_title]', 'Title: (required)')
        with_tag( 'input[id=article_title][type=text][value]')
      end
      with_tag('div[class*=buttons]') do
        with_tag('button[type=submit][class*=positive]') do
          with_tag('img[src=/images/icons/tick.png]')
        end
        with_tag('a') do
          with_tag('img[src=/images/icons/arrow_undo.png]')
        end
      end
    end
  end
end