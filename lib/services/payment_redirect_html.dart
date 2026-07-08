import 'dart:html' as html;

void redirectToCheckout(String url) {
  html.window.location.assign(url);
}