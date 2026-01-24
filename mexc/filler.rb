require 'capybara'
require 'capybara/dsl'
require 'selenium-webdriver'
require 'bigdecimal'
require 'bigdecimal/util'

module BrowserSession
  include Capybara::DSL

  # Path for Chrome user data (cookies, localStorage, etc.)
  PROFILE_PATH = File.expand_path(ENV.fetch('SELENIUM_PROFILE_PATH', '~/storage/work/selenium-profile'))

  def self.setup(headless: false)
    Capybara.register_driver :chrome_persistent do |app|
      options = Selenium::WebDriver::Chrome::Options.new
      options.add_argument("--user-data-dir=#{PROFILE_PATH}")
      options.add_argument('--disable-gpu')
      options.add_argument('--no-sandbox')
      options.add_argument('--headless') if headless
      # Optional: set window size
      options.add_argument('--window-size=1440,800')

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

  # Initialize and start a persistent browser session
  # headless: true to run without UI after initial login
  def initialize(headless: false)
    BrowserSession.setup(headless: headless)
  end

  def open_browser
    visit 'https://www.mexc.com'
    puts "When done, return here and press ENTER to close browser..."
    STDIN.gets
    puts "Browser closed."
  end

  # Opens the login page; perform manual login + TFA here
  def start_login_session
    visit LOGIN_URL
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
    visit trading_portal_url(ticker)

    if has_selector?('.header_loginBtn__Zb0Hx', text: 'Log In', wait: 5)
      start_login_session

      visit trading_portal_url(ticker)
    end

    within ".actions_dirBtnWrapper__CNiH6" do
      find('div.actions_buyBtn__ySCEX').click # click BUY
    end

    find('input[data-testid="spot-trade-buyPrice"]').set(price.to_d.to_s('F'))
    find('input[data-testid="spot-trade-buyQuantity"]').set(quantity.to_s)

    tp ||= tp_percentage ? price * (1 + tp_percentage/100.0) : nil

    if tp
      within '.actions_profitLoseWrappper__u5k9Y' do
        find('label.ant-checkbox-v2-wrapper', text: 'TP / SL').click
        sleep 0.25
        find('.actions_inputWrapper__OKcnB input', match: :first).set(tp.to_d.to_s('F'))
      end
    end

    click_on "Buy #{ticker}"
    sleep 0.25

    within '.ant-modal-body' do
      click_on "Buy #{ticker}"
      sleep 0.25
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
    visit trading_portal_url(ticker)

    if has_selector?('.header_loginBtn__Zb0Hx', text: 'Log In', wait: 5)
      start_login_session

      visit trading_portal_url(ticker)
    end

    within ".actions_dirBtnWrapper__CNiH6" do
      find('div.actions_sellBtn__WE9kM').click # click SELL
    end

    find('input[data-testid="spot-trade-sellPrice"]').set(price.to_d.to_s('F'))
    find('input[data-testid="spot-trade-sellQuantity"]').set(quantity.to_s)

    click_on "Sell #{ticker}"
    sleep 1

    within '.ant-modal-body' do
      click_on "Sell #{ticker}"
      sleep 1
    end

    if has_text?('Ordered successfully', wait: 5)
      puts "✅ #{ticker} sell order for #{quantity.to_s} at #{price.to_d.to_s('F')} placed successfully."
      true
    else
      warn "⚠️ #{ticker} sell order may not have been placed. Check the browser window."
      false
    end
  end

  def trading_portal_url(ticker)
    "https://www.mexc.com/exchange/#{ticker}_USDT"
  end
end

# === Example Usage ===
#
# 1) First run (GUI mode):
bot = MexcFiller.new(headless: false)
bot.start_login_session
# bot.open_browser
#
# 2) Subsequent runs (headless or not):
# bot = MexcFiller.new(headless: false)

# bot.place_buy_order(ticker: "SOVM", price: 0.000317, quantity: 50000.0)
# bot.place_buy_order(ticker: "SOVM", price: 0.00034, quantity: 94588.23)

# bot.place_sell_order(ticker: "IAGO", price: 0.00003096, quantity: 370244.64)
# bot.place_sell_order(ticker: "IAGO", price: 0.00003004, quantity: 370244.56)
