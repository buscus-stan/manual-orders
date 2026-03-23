require 'capybara'
require 'capybara/dsl'
require 'selenium-webdriver'
require 'bigdecimal'
require 'bigdecimal/util'

module BrowserSession
  include Capybara::DSL

  # Path for Chrome user data (cookies, localStorage, etc.)
  PROFILE_PATH = File.expand_path(ENV.fetch('SELENIUM_PROFILE_PATH', '~/storage/work/selenium-profile'))

  def self.setup
    Capybara.register_driver :chrome_persistent do |app|
      options = Selenium::WebDriver::Chrome::Options.new
      options.add_argument("--user-data-dir=#{PROFILE_PATH}")
      options.add_argument('--window-size=1440,800')
      options.add_argument('--disable-blink-features=AutomationControlled')
      options.add_argument('--disable-infobars')
      options.add_preference('credentials_enable_service', false)
      options.add_preference('profile.password_manager_enabled', false)

      Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
    end

    Capybara.current_driver = :chrome_persistent
    Capybara.default_max_wait_time = 10
  end
end

class MexcFiller
  include BrowserSession
  include Capybara::DSL

  LOGIN_URL = 'https://www.mexc.com/login'

  STEALTH_JS = <<~JS
    // Remove webdriver flag
    Object.defineProperty(navigator, 'webdriver', { get: () => undefined });

    // Patch chrome.runtime to look like a real Chrome instance
    if (!window.chrome) { window.chrome = {}; }
    if (!window.chrome.runtime) {
      window.chrome.runtime = {
        connect: function() {},
        sendMessage: function() {}
      };
    }

    // Ensure navigator.plugins is non-empty
    Object.defineProperty(navigator, 'plugins', {
      get: () => [1, 2, 3, 4, 5]
    });

    // Ensure navigator.languages is realistic
    Object.defineProperty(navigator, 'languages', {
      get: () => ['en-US', 'en']
    });
  JS

  def initialize
    BrowserSession.setup
  end

  def open_browser
    visit_and_settle('https://www.mexc.com')
    puts "When done, return here and press ENTER to close browser..."
    STDIN.gets
    puts "Browser closed."
  end

  # Opens the login page; perform manual login + TFA here
  def start_login_session
    visit_and_settle(LOGIN_URL)
    puts "Please log in and complete any TFA in the opened browser."
    puts "When done, return here and press ENTER to continue..."
    STDIN.gets
    puts "Login session persisted in profile at #{BrowserSession::PROFILE_PATH}."
  end

  def place_order(side:, price:, quantity:)
    if side == "buy"
      place_buy_order(price: price, quantity: quantity)
    elsif side == "sell"
      place_sell_order(price: price, quantity: quantity)
    end
  end

  def place_buy_order(ticker:, price:, quantity:, tp: nil, tp_percentage: nil)
    visit_and_settle(trading_portal_url(ticker))

    if has_selector?('.header_loginBtn__Zb0Hx', text: 'Log In', wait: 5)
      start_login_session
      visit_and_settle(trading_portal_url(ticker))
    end

    random_scroll

    within ".actions_dirBtnWrapper__CNiH6" do
      human_click(find('div.actions_buyBtn__ySCEX'))
    end

    human_type(find('input[data-testid="spot-trade-buyPrice"]'), price.to_d.to_s('F'))
    human_type(find('input[data-testid="spot-trade-buyQuantity"]'), quantity.to_s)

    tp ||= tp_percentage ? price * (1 + tp_percentage/100.0) : nil

    if tp
      within '.actions_profitLoseWrappper__u5k9Y' do
        human_click(find('label.ant-checkbox-v2-wrapper', text: 'TP / SL'))
        human_delay(0.2, 0.5)
        human_type(find('.actions_inputWrapper__OKcnB input', match: :first), tp.to_d.to_s('F'))
      end
    end

    human_click(find('button', text: "Buy #{ticker}"))
    human_delay(0.3, 0.8)

    within '.ant-modal-body' do
      human_click(find('button', text: "Buy #{ticker}"))
      human_delay(0.3, 0.8)
    end

    if has_text?('Ordered successfully', wait: 5)
      puts "✅ #{ticker} buy order for #{quantity.to_s} at #{price.to_d.to_s('F')} placed successfully."
      true
    else
      warn "⚠️ #{ticker} buy order may not have been placed. Check the browser window."
      false
    end
  end

  def place_sell_order(ticker:, price:, quantity:)
    visit_and_settle(trading_portal_url(ticker))

    if has_selector?('.header_loginBtn__Zb0Hx', text: 'Log In', wait: 5)
      start_login_session
      visit_and_settle(trading_portal_url(ticker))
    end

    random_scroll

    within ".actions_dirBtnWrapper__CNiH6" do
      human_click(find('div.actions_sellBtn__WE9kM'))
    end

    human_type(find('input[data-testid="spot-trade-sellPrice"]'), price.to_d.to_s('F'))
    human_type(find('input[data-testid="spot-trade-sellQuantity"]'), quantity.to_s)

    human_click(find('button', text: "Sell #{ticker}"))
    human_delay(0.5, 1.2)

    within '.ant-modal-body' do
      human_click(find('button', text: "Sell #{ticker}"))
      human_delay(0.5, 1.2)
    end

    if has_text?('Ordered successfully', wait: 5)
      puts "✅ #{ticker} sell order for #{quantity.to_s} at #{price.to_d.to_s('F')} placed successfully."
      true
    else
      warn "⚠️ #{ticker} sell order may not have been placed. Check the browser window."
      false
    end
  end

  private

  def trading_portal_url(ticker)
    "https://www.mexc.com/exchange/#{ticker}_USDT"
  end

  def inject_stealth_js
    page.driver.browser.execute_cdp('Page.addScriptToEvaluateOnNewDocument', source: STEALTH_JS)
  rescue => e
    warn "Stealth JS injection failed: #{e.message}"
  end

  def visit_and_settle(url)
    visit(url)
    inject_stealth_js
    human_delay(1.5, 3.0)
  end

  def human_delay(min = 0.3, max = 1.2)
    sleep rand(min..max)
  end

  def human_type(element, text)
    element.click
    human_delay(0.1, 0.3)
    element.native.clear
    text.to_s.each_char do |char|
      element.native.send_keys(char)
      sleep rand(0.04..0.12)
    end
  end

  def human_click(element)
    driver = page.driver.browser
    action = driver.action
    action.move_to(element.native, rand(-3..3), rand(-3..3))
    action.pause(rand(0.1..0.3))
    action.click
    action.perform
  end

  def random_scroll
    page.execute_script("window.scrollBy(0, #{rand(50..200)})")
    human_delay(0.3, 0.8)
  end
end

# === Example Usage ===
#
# 1) First run (GUI mode):
bot = MexcFiller.new
bot.start_login_session
# bot.open_browser
#
# 2) Subsequent runs:
# bot = MexcFiller.new

# bot.place_buy_order(ticker: "SOVM", price: 0.000317, quantity: 50000.0)
# bot.place_buy_order(ticker: "SOVM", price: 0.00034, quantity: 94588.23)

# bot.place_sell_order(ticker: "IAGO", price: 0.00003096, quantity: 370244.64)
# bot.place_sell_order(ticker: "IAGO", price: 0.00003004, quantity: 370244.56)
