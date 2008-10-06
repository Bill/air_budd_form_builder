require File.dirname(__FILE__) + '/../spec_helper'

describe 'builder' do

  shared_examples_for 'always' do
    it 'shows button group' do
      response.should have_tag('div[class*=buttons]')
    end
    
    it 'shows undo link' do
      with_tag('div[class*=buttons]') do
        with_tag('a') do
          with_tag('img[src=/images/icons/arrow_undo.png]')
        end
      end
    end
  end
  
  shared_examples_for 'controls mode' do
    it 'render form and controls' do
      response.should have_tag('form') do
        with_tag( 'input[id=article_title][type=text]')
        with_tag( 'button[type=submit][class*=positive]')
      end
    end
  end
  
  shared_examples_for 'indicate errors' do
    it 'have error class on container' do
      response.should have_tag('p[class*=error]')
    end
    it 'display error message' do
      response.should have_tag( 'label[for=article_title]', "Title: (required) Can't be blank.")
    end
  end
  

  def article
    @article ||= Article.new( :title => 'first', :body => 'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.', :published => true)
  end
  
  before(:each) do
    assigns[:article] = article
    article.valid?
    render :partial => 'article/show_default'
  end
  
  it_should_behave_like 'always'
  
  describe 'default rendering an object with no errors' do
    it_should_behave_like 'controls mode'
  end
  
  describe 'default rendering an object with errors' do
    def article
      super.title = nil # make the article invalid
      super
    end
    it_should_behave_like 'controls mode'
    it_should_behave_like 'indicate errors'
  end
end