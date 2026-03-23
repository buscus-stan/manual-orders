# AGENTS.md

This file provides guidance to AI agents when working with code in this repository.

# manual-orders

A Ruby browser automation script for placing spot limit orders on Mexc via a real Chrome browser (Capybara + Selenium). Bypasses API limitations by driving the Mexc web UI directly.

## Stack

- **Runtime**: Ruby (see `.tool-versions` for version via asdf)
- **Browser automation**: Capybara + Selenium WebDriver (Chrome)
- **Key deps**: `capybara`, `selenium-webdriver`

## Running

```bash
bundle install
ruby mexc/filler.rb   # edit the example usage section at the bottom first
```

## Key File

**`mexc/filler.rb`** — the entire script. Two classes:
- `BrowserSession` — Capybara/Selenium setup; uses a persistent Chrome profile so login sessions survive between runs (profile path via `SELENIUM_PROFILE_PATH` env var, defaults to `~/storage/work/selenium-profile`)
- `MexcFiller` — order placement logic

## How It Works

1. First run: call `bot.start_login_session` — opens login page, waits for manual login + TFA, then persists the session to the Chrome profile
2. Subsequent runs: session is already authenticated; call `place_buy_order` or `place_sell_order` directly

### Anti-detection

Injects stealth JS on every page load to mask WebDriver fingerprints (removes `navigator.webdriver`, patches `chrome.runtime`, spoofs plugins/languages). Also uses human-like interactions: random mouse offsets, random delays between keystrokes and clicks.

### Order methods

```ruby
bot.place_buy_order(ticker: "BTC", price: 95000.0, quantity: 0.001)
bot.place_buy_order(ticker: "BTC", price: 95000.0, quantity: 0.001, tp: 98000.0)
bot.place_buy_order(ticker: "BTC", price: 95000.0, quantity: 0.001, tp_percentage: 3.0)
bot.place_sell_order(ticker: "BTC", price: 100000.0, quantity: 0.001)
```

All orders are placed as limit orders on the `{ticker}_USDT` pair.

## No Tests

This is a single-purpose script — there are no specs.
