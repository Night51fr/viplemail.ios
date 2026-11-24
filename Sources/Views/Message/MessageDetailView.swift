import SwiftUI
#if canImport(WebKit)
import WebKit
#endif

// MARK: - Lecture de Courrier Classique « Viple Mail » (Style Apple Mail / Client Mail Traditionnel — Zéro Bulle de Chat)

#if canImport(WebKit) && canImport(UIKit)
@MainActor
private final class WeakHeightMessageHandler: NSObject, WKScriptMessageHandler {
    weak var coordinator: VipleMailHTMLWebView.Coordinator?

    init(_ coordinator: VipleMailHTMLWebView.Coordinator) {
        self.coordinator = coordinator
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if let num = message.body as? NSNumber {
            let h = CGFloat(truncating: num)
            if h > 0 {
                coordinator?.applyMeasuredHeight(h)
            }
        }
    }
}

private struct VipleMailHTMLWebView: UIViewRepresentable {
    let htmlBody: String
    let renderDark: Bool
    @Binding var dynamicHeight: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.userContentController.add(WeakHeightMessageHandler(context.coordinator), name: "vipleMailHeight")
        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.scrollView.backgroundColor = .clear
        wv.scrollView.isScrollEnabled = false
        wv.scrollView.bounces = false
        wv.scrollView.showsHorizontalScrollIndicator = false
        wv.navigationDelegate = context.coordinator
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.parent = self
        uiView.overrideUserInterfaceStyle = renderDark ? .dark : .light

        let schemeMeta = renderDark ? "dark light" : "light"
        let baseCss: String
        if renderDark {
            baseCss = """
            :root { color-scheme: dark light; }
            html, body {
              margin: 0 !important; padding: 0 !important;
              width: 100%;
              font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif;
              font-size: 15.5px; line-height: 1.58;
              color: #F1F6FD;
              word-wrap: break-word; overflow-wrap: anywhere;
              background: transparent !important;
              -webkit-text-size-adjust: 100%;
            }
            img { max-width: 100% !important; height: auto !important; border-radius: 6px; }
            table { border-color: rgba(148, 179, 226, 0.18); border-collapse: collapse; }
            hr { border: none !important; border-top: 1px solid rgba(148, 179, 226, 0.20) !important; }
            pre, code {
              background-color: #192338 !important;
              color: #E2EEFF !important;
              border-radius: 6px;
              padding: 2px 5px;
            }
            blockquote {
              margin: 12px 0; padding-left: 12px;
              border-left: 2.5px solid #3B5278 !important;
              color: #B8C6DC;
            }
            a { color: #58A6FF; }
            """
        } else {
            baseCss = """
            :root { color-scheme: light; }
            html, body {
              margin: 0 !important; padding: 0 !important;
              width: 100%;
              font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif;
              font-size: 15.5px; line-height: 1.58;
              color: #0f172a;
              word-wrap: break-word; overflow-wrap: anywhere;
              background: transparent;
              -webkit-text-size-adjust: 100%;
            }
            img { max-width: 100% !important; height: auto !important; border-radius: 6px; }
            blockquote { margin: 12px 0; padding-left: 12px; border-left: 2.5px solid #cbd5e1; color: #475569; }
            a { color: #0078D4; }
            """
        }

        let isNativeCenelisRichMail = htmlBody.contains("data-cenelis-rich-mail")
        let runtimeScript: String = """
        <script>
        (function() {
          var IS_DARK = \(renderDark ? "true" : "false");
          var IS_NATIVE_CENELIS_RICH = \(isNativeCenelisRichMail ? "true" : "false");
          var ROOT_DARK_BG = { r: 16, g: 23, b: 38, a: 1 }; // #101726

          function clamp(v, lo, hi) { return Math.min(hi, Math.max(lo, v)); }

          function parseColor(str) {
            if (!str) return null;
            var s = str.trim().toLowerCase();
            if (s === 'transparent' || s === 'none') return { r: 0, g: 0, b: 0, a: 0 };
            var m = s.match(/rgba?\\(\\s*([\\d.]+)\\s*,\\s*([\\d.]+)\\s*,\\s*([\\d.]+)(?:\\s*[,/]\\s*([\\d.]+))?\\s*\\)/);
            if (m) {
              return {
                r: clamp(Math.round(+m[1]), 0, 255),
                g: clamp(Math.round(+m[2]), 0, 255),
                b: clamp(Math.round(+m[3]), 0, 255),
                a: m[4] !== undefined ? clamp(+m[4], 0, 1) : 1
              };
            }
            var hx = s.match(/^#([0-9a-f]{3}|[0-9a-f]{6})$/);
            if (hx) {
              var h = hx[1];
              if (h.length === 3) h = h[0]+h[0]+h[1]+h[1]+h[2]+h[2];
              var n = parseInt(h, 16);
              return { r: (n >> 16) & 255, g: (n >> 8) & 255, b: n & 255, a: 1 };
            }
            return null;
          }

          function srgbChannel(v) {
            var x = v / 255;
            return x <= 0.03928 ? x / 12.92 : Math.pow((x + 0.055) / 1.055, 2.4);
          }

          // Luminance relative officielle WCAG 2.1 (0.0 noir .. 1.0 blanc)
          function wcagLum(c) {
            return 0.2126 * srgbChannel(c.r) + 0.7152 * srgbChannel(c.g) + 0.0722 * srgbChannel(c.b);
          }

          function contrastRatio(l1, l2) {
            var hi = Math.max(l1, l2), lo = Math.min(l1, l2);
            return (hi + 0.05) / (lo + 0.05);
          }

          function rgbToHsl(c) {
            var r = c.r / 255, g = c.g / 255, b = c.b / 255;
            var max = Math.max(r, g, b), min = Math.min(r, g, b);
            var h = 0, s = 0, l = (max + min) / 2;
            if (max !== min) {
              var d = max - min;
              s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
              switch (max) {
                case r: h = (g - b) / d + (g < b ? 6 : 0); break;
                case g: h = (b - r) / d + 2; break;
                case b: h = (r - g) / d + 4; break;
              }
              h /= 6;
            }
            return { h: h * 360, s: s, l: l };
          }

          function hslToRgb(h, s, l) {
            h = ((h % 360) + 360) % 360 / 360;
            s = clamp(s, 0, 1); l = clamp(l, 0, 1);
            if (s === 0) {
              var v = Math.round(l * 255);
              return { r: v, g: v, b: v, a: 1 };
            }
            function hue2rgb(p, q, t) {
              if (t < 0) t += 1;
              if (t > 1) t -= 1;
              if (t < 1/6) return p + (q - p) * 6 * t;
              if (t < 1/2) return q;
              if (t < 2/3) return p + (q - p) * (2/3 - t) * 6;
              return p;
            }
            var q = l < 0.5 ? l * (1 + s) : l + s - l * s;
            var p = 2 * l - q;
            return {
              r: Math.round(hue2rgb(p, q, h + 1/3) * 255),
              g: Math.round(hue2rgb(p, q, h) * 255),
              b: Math.round(hue2rgb(p, q, h - 1/3) * 255),
              a: 1
            };
          }

          function toCssRgb(c) {
            return 'rgb(' + c.r + ', ' + c.g + ', ' + c.b + ')';
          }

          function blendOver(fg, bg) {
            var a = clamp(fg.a, 0, 1);
            if (a >= 0.99) return { r: fg.r, g: fg.g, b: fg.b, a: 1 };
            return {
              r: Math.round(fg.r * a + bg.r * (1 - a)),
              g: Math.round(fg.g * a + bg.g * (1 - a)),
              b: Math.round(fg.b * a + bg.b * (1 - a)),
              a: 1
            };
          }

          function extractGradientStops(bgImage) {
            if (!bgImage || bgImage === 'none' || bgImage.indexOf('gradient') === -1 || bgImage.indexOf('url(') !== -1) return null;
            var stops = [];
            var rgbs = bgImage.match(/rgba?\\([^)]+\\)|#[0-9a-fA-F]{3,6}/g);
            if (!rgbs) return null;
            for (var i = 0; i < rgbs.length; i++) {
              var parsed = parseColor(rgbs[i]);
              if (parsed && parsed.a > 0.15) stops.push(parsed);
            }
            return stops.length > 0 ? stops : null;
          }

          function isLikelyButton(el, cs) {
            var tag = el.tagName;
            if (tag === 'BUTTON') return true;
            if (tag === 'A' && (cs.display === 'inline-block' || cs.display === 'block' || parseFloat(cs.paddingTop) >= 6 || parseFloat(cs.paddingLeft) >= 10)) {
              return true;
            }
            return false;
          }

          function adaptEmailForDarkMode() {
            if (!IS_DARK || !document.body) return;

            var skipTags = { SCRIPT: 1, STYLE: 1, NOSCRIPT: 1, HEAD: 1, META: 1, LINK: 1, TITLE: 1, BR: 1 };
            var all = document.body.querySelectorAll('*');
            var list = [document.body];
            for (var i = 0; i < all.length; i++) {
              if (!skipTags[all[i].tagName]) list.push(all[i]);
            }

            // PASSE 1 : Normalisation intelligente des fonds, dégradés, boîtes pastel et bordures
            for (var j = 0; j < list.length; j++) {
              var el = list[j];
              var cs = window.getComputedStyle(el);

              // 1a. Dégradés CSS (ex: linear-gradient(#ffffff, #f1f5f9) dont backgroundColor vaut transparent !)
              var gradStops = extractGradientStops(cs.backgroundImage);
              if (gradStops) {
                var sumLum = 0, minLum = 1;
                for (var g = 0; g < gradStops.length; g++) {
                  var gl = wcagLum(gradStops[g]);
                  sumLum += gl;
                  if (gl < minLum) minLum = gl;
                }
                var avgLum = sumLum / gradStops.length;
                if (minLum > 0.48 || avgLum > 0.62) {
                  el.style.setProperty('background-image', 'none', 'important');
                  el.style.setProperty('background-color', el === document.body ? 'transparent' : '#162033', 'important');
                } else {
                  el.setAttribute('data-vm-grad-lum', String(avgLum.toFixed(3)));
                }
              }

              // 1b. Couleurs de fond (attributs HTML bgcolor inclus)
              var bg = parseColor(cs.backgroundColor);
              if (bg && bg.a > 0.08) {
                var compBg = blendOver(bg, { r: 255, g: 255, b: 255, a: 1 });
                var bgL = wcagLum(compBg);
                var hsl = rgbToHsl(compBg);
                var btn = isLikelyButton(el, cs);

                if (el === document.body || el === document.documentElement) {
                  if (bgL > 0.35) {
                    el.style.setProperty('background-color', 'transparent', 'important');
                  }
                } else if (bgL > 0.85 && hsl.s < 0.22) {
                  // Blanc pur / quasi-blanc -> surface ardoise sombre principale
                  el.style.setProperty('background-color', '#101726', 'important');
                } else if (bgL >= 0.48 && hsl.s < 0.20) {
                  // Gris clair / entête de tableau / carte secondaire -> ardoise surélevée
                  el.style.setProperty('background-color', '#182338', 'important');
                } else if (bgL >= 0.46 && hsl.s >= 0.20 && !(btn && hsl.s >= 0.55 && bgL < 0.72)) {
                  // Boîtes d'alerte / badges pastel (#DBEAFE, #FEF3C7, #DCFCE7, #FEE2E2, #F3E8FF) :
                  // conserve la teinte exacte (hue) tout en l'assombrissant en verre teinté sombre !
                  var darkTinted = hslToRgb(hsl.h, Math.min(0.46, Math.max(0.24, hsl.s * 0.65)), 0.17);
                  el.style.setProperty('background-color', toCssRgb(darkTinted), 'important');
                }
              }

              // 1c. Bordures claires & ombres portées agressives
              var sides = ['Top', 'Right', 'Bottom', 'Left'];
              for (var sIdx = 0; sIdx < sides.length; sIdx++) {
                var side = sides[sIdx];
                if (parseFloat(cs['border' + side + 'Width']) > 0) {
                  var bc = parseColor(cs['border' + side + 'Color']);
                  if (bc && bc.a > 0.15 && wcagLum(bc) > 0.45 && rgbToHsl(bc).s < 0.35) {
                    el.style.setProperty('border-' + side.toLowerCase() + '-color', 'rgba(148, 179, 226, 0.20)', 'important');
                  }
                }
              }

              // 1d. Icônes SVG monochromes noires en ligne
              if (el.tagName === 'SVG' || el.tagName === 'PATH') {
                var fillCol = parseColor(cs.fill);
                if (fillCol && fillCol.a > 0.4 && wcagLum(fillCol) < 0.06) {
                  el.style.setProperty('fill', '#E2EEFF', 'important');
                }
              }
            }

            // Fonction de résolution du fond réel effectif derrière n'importe quel élément après la Passe 1
            function resolveEffectiveBg(node) {
              var cur = node;
              while (cur && cur !== document.documentElement) {
                var gradAttr = cur.getAttribute && cur.getAttribute('data-vm-grad-lum');
                if (gradAttr !== null && gradAttr !== '') {
                  var gl = parseFloat(gradAttr);
                  var v = Math.round(Math.pow(clamp(gl, 0, 1), 1 / 2.2) * 255);
                  return { r: v, g: v, b: v, a: 1 };
                }
                var ccs = window.getComputedStyle(cur);
                if (ccs.backgroundImage && ccs.backgroundImage.indexOf('url(') !== -1) {
                  // Image de fond : on ne force pas l'inversion aveugle par-dessus une bannière photo
                  return null;
                }
                var b = parseColor(ccs.backgroundColor);
                if (b && b.a > 0.08) {
                  if (b.a >= 0.92) return b;
                  var parentBg = resolveEffectiveBg(cur.parentElement) || ROOT_DARK_BG;
                  return blendOver(b, parentBg);
                }
                cur = cur.parentElement;
              }
              return ROOT_DARK_BG;
            }

            // PASSE 2 : Garantie mathématique de contraste WCAG >= 4.8:1 sur tous les textes et liens
            for (var k = 0; k < list.length; k++) {
              var node = list[k];
              var ncs = window.getComputedStyle(node);
              var fg = parseColor(ncs.color);
              if (!fg || fg.a < 0.12) continue;

              var effBg = resolveEffectiveBg(node);
              if (!effBg) continue;

              var bgLum = wcagLum(effBg);
              var fgLum = wcagLum(fg);
              var ratio = contrastRatio(fgLum, bgLum);

              if (ratio >= 4.6) continue; // Déjà parfaitement lisible (ex: texte blanc sur bouton bleu #0078D4) !

              var fgHsl = rgbToHsl(fg);
              if (bgLum < 0.35) {
                // Surface sombre : éclaircissement haute lisibilité
                if (fgHsl.s < 0.16 && node.tagName !== 'A') {
                  // Nuances de noir / gris anthracite -> hiérarchie typographique claire
                  if (fgLum < 0.05) {
                    node.style.setProperty('color', '#F1F6FD', 'important');
                  } else if (fgLum < 0.16) {
                    node.style.setProperty('color', '#CBD6E8', 'important');
                  } else {
                    node.style.setProperty('color', '#A8B8D0', 'important');
                  }
                } else {
                  // Texte ou lien coloré sombre (ex: bleu marine #003366, #1A0DAB, violet, vert forêt, bordeaux) :
                  // conserve exactement la teinte (hue) et augmente la luminosité jusqu'à atteindre un contraste >= 5.2:1 !
                  var targetHue = node.tagName === 'A' && fgHsl.s < 0.16 ? 210 : fgHsl.h;
                  var targetSat = node.tagName === 'A' && fgHsl.s < 0.16 ? 0.88 : Math.min(0.90, Math.max(0.48, fgHsl.s));
                  var best = hslToRgb(targetHue, targetSat, Math.max(fgHsl.l, 0.72));
                  for (var stepL = Math.max(fgHsl.l, 0.62); stepL <= 0.93; stepL += 0.04) {
                    var cand = hslToRgb(targetHue, targetSat, stepL);
                    best = cand;
                    if (contrastRatio(wcagLum(cand), bgLum) >= 5.2) break;
                  }
                  node.style.setProperty('color', toCssRgb(best), 'important');
                }
              } else {
                // Surface restée volontairement claire/vive (ex: bouton jaune/ambre vif #FBBF24) : texte sombre net
                node.style.setProperty('color', '#0F172A', 'important');
              }
            }
          }

          function fitWideTablesAndReportHeight() {
            if (!document.body) return;
            var vw = window.innerWidth || document.documentElement.clientWidth || 360;
            if (vw <= 0) return;

            // Réinitialise une éventuelle mise à l'échelle précédente avant mesure
            document.body.style.zoom = '';
            document.body.style.transform = '';
            document.body.style.width = '';

            // Supprime les min-width rigides excessifs sur les conteneurs non-tabulaires
            var wrappers = document.body.querySelectorAll('div, section, article, main, header, footer, center');
            for (var i = 0; i < wrappers.length; i++) {
              var wcs = window.getComputedStyle(wrappers[i]);
              var mw = parseFloat(wcs.minWidth);
              if (!isNaN(mw) && mw > vw) {
                wrappers[i].style.setProperty('min-width', '0px', 'important');
                wrappers[i].style.setProperty('max-width', '100%', 'important');
              }
            }

            // Si un tableau HTML fixe (ex: newsletter 600px/640px) dépasse encore la largeur de l'écran iPhone,
            // adapte proportionnellement l'échelle pour qu'aucune colonne droite ne soit jamais tronquée !
            var contentW = Math.max(document.documentElement.scrollWidth, document.body.scrollWidth);
            var scale = 1;
            if (contentW > vw + 4) {
              scale = vw / contentW;
              document.body.style.width = contentW + 'px';
              document.body.style.transformOrigin = 'top left';
              document.body.style.transform = 'scale(' + scale.toFixed(4) + ')';
            }

            var rawH = Math.max(
              document.body.scrollHeight,
              document.body.offsetHeight,
              document.documentElement.scrollHeight
            );
            var finalH = Math.ceil(rawH * scale) + 18;
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.vipleMailHeight) {
              window.webkit.messageHandlers.vipleMailHeight.postMessage(finalH);
            }
            return finalH;
          }

          var didBindImages = false;
          function bindImageLoadListeners() {
            if (didBindImages) return;
            var imgs = document.images || [];
            if (imgs.length === 0) return;
            didBindImages = true;
            for (var i = 0; i < imgs.length; i++) {
              imgs[i].addEventListener('load', fitWideTablesAndReportHeight);
            }
          }

          function runAll() {
            document.documentElement.setAttribute('data-viple-theme', IS_DARK ? 'dark' : 'light');
            if (!IS_NATIVE_CENELIS_RICH) {
              try { adaptEmailForDarkMode(); } catch (e) {}
            }
            try { bindImageLoadListeners(); } catch (e) {}
            try { fitWideTablesAndReportHeight(); } catch (e) {}
          }

          if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', runAll);
          } else {
            runAll();
          }
          window.addEventListener('load', function() {
            bindImageLoadListeners();
            fitWideTablesAndReportHeight();
          });
          setTimeout(fitWideTablesAndReportHeight, 140);
          setTimeout(fitWideTablesAndReportHeight, 500);
          setTimeout(fitWideTablesAndReportHeight, 1200);
          setTimeout(fitWideTablesAndReportHeight, 2400);
        })();
        </script>
        """

        let wrapped = """
        <!doctype html>
        <html data-viple-theme="\(renderDark ? "dark" : "light")">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="color-scheme" content="\(schemeMeta)">
        <meta name="supported-color-schemes" content="\(schemeMeta)">
        <style>\(baseCss)</style>
        </head>
        <body>\(htmlBody)\(runtimeScript)</body>
        </html>
        """
        let cacheSignature = "\(renderDark ? "D" : "L")|\(wrapped)"
        if context.coordinator.lastLoadedHTML != cacheSignature {
            context.coordinator.lastLoadedHTML = cacheSignature
            uiView.loadHTMLString(wrapped, baseURL: URL(string: "https://mail.viplemail.fr"))
        }
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: VipleMailHTMLWebView
        var lastLoadedHTML: String = ""

        init(_ parent: VipleMailHTMLWebView) {
            self.parent = parent
        }

        func applyMeasuredHeight(_ h: CGFloat) {
            let clamped = max(120, h)
            if abs(parent.dynamicHeight - clamped) > 1.5 {
                parent.dynamicHeight = clamped
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor [weak self, weak webView] in
                guard let self, let webView else { return }
                if let result = try? await webView.evaluateJavaScript("Math.max(document.body.scrollHeight, document.documentElement.scrollHeight)") {
                    if let num = result as? NSNumber {
                        let h = CGFloat(truncating: num)
                        if h > 0 && self.parent.dynamicHeight <= 225 {
                            self.applyMeasuredHeight(h + 18)
                        }
                    }
                }
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction
        ) async -> WKNavigationActionPolicy {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url {
                await UIApplication.shared.open(url)
                return .cancel
            }
            return .allow
        }
    }
}
#endif

public struct MessageDetailView: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    public let message: VipleMailMessage

    @State private var showFullHeaders: Bool = false
    @State private var showPreviousThreadEmails: Bool = false
    @State private var isShowingMoveFolderSheet: Bool = false
    @State private var forceOriginalLightEmail: Bool = false
    @State private var htmlContentHeight: CGFloat = 220
    @State private var pinUnlockedMessage: VipleMailMessage? = nil

    public init(message: VipleMailMessage) {
        self.message = message
    }

    private var effectiveRenderHtmlDark: Bool {
        colorScheme == .dark && vm.adaptHtmlEmailsInDarkMode && !forceOriginalLightEmail
    }

    private var currentMessage: VipleMailMessage {
        if let unlocked = pinUnlockedMessage, unlocked.id == message.id {
            return unlocked
        }
        return vm.messages.first(where: { $0.id == message.id }) ?? message
    }

    private var previousEmailsInThread: [VipleMailMessage] {
        vm.activeThreadMessages.filter { $0.id != currentMessage.id }
    }

    private var recipientSummaryLabel: String {
        let rcpt = currentMessage.recipientEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        if rcpt.isEmpty { return "À : moi" }
        if rcpt.lowercased() == vm.currentEmail.lowercased() {
            return "À : moi"
        }
        return "À : \(rcpt)"
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    classicSenderHeaderSection

                    Divider()
                        .padding(.leading, 16)

                    classicSubjectHeaderSection

                    if !currentMessage.attachments.isEmpty {
                        Divider()
                            .padding(.leading, 16)
                        classicAttachmentsSection(currentMessage.attachments)
                    }

                    Divider()

                    classicEmailBodySection(currentMessage)

                    if !previousEmailsInThread.isEmpty {
                        Divider()
                            .padding(.top, 12)
                        classicQuotedThreadSection
                    }
                }
                .background(VipleMailPalette.surface)
            }
            .background(VipleMailPalette.surface)

            classicMailBottomToolbar
        }
        .background(VipleMailPalette.surface.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            pinUnlockedMessage = nil
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active {
                pinUnlockedMessage = nil
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    vm.closeMessage()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                        Text(vm.activeFolderTitle)
                            .font(.system(size: 15.5, weight: .regular))
                            .lineLimit(1)
                    }
                }
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                if colorScheme == .dark && hasRichHTML(currentMessage.bodyHtml) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if vm.adaptHtmlEmailsInDarkMode {
                                forceOriginalLightEmail.toggle()
                            } else {
                                vm.adaptHtmlEmailsInDarkMode = true
                                forceOriginalLightEmail = false
                            }
                        }
                    } label: {
                        Image(systemName: effectiveRenderHtmlDark ? "sun.max" : "moon.stars.fill")
                    }
                    .accessibilityLabel(effectiveRenderHtmlDark ? "Afficher ce courrier sur fond clair" : "Adapter ce courrier au mode sombre")
                }

                Button {
                    Task {
                        await vm.performMessageAction(
                            messageIds: [currentMessage.id],
                            action: "toggle_read",
                            toast: "Marqué comme non lu"
                        )
                        vm.closeMessage()
                    }
                } label: {
                    Image(systemName: "envelope.badge")
                }
                .accessibilityLabel("Marquer comme non lu")

                Menu {
                    Button {
                        vm.presentComposer(.reply(currentMessage))
                    } label: {
                        Label("Répondre", systemImage: "arrowshape.turn.up.left")
                    }

                    Button {
                        vm.presentComposer(.replyAll(currentMessage))
                    } label: {
                        Label("Répondre à tous", systemImage: "arrowshape.turn.up.left.2")
                    }

                    Button {
                        vm.presentComposer(.forward(currentMessage))
                    } label: {
                        Label("Transférer", systemImage: "arrowshape.turn.up.right")
                    }

                    Divider()

                    Button {
                        Task {
                            await vm.performMessageAction(
                                messageIds: [currentMessage.id],
                                action: "toggle_star",
                                toast: currentMessage.isStarred ? "Retiré des favoris" : "Ajouté aux favoris"
                            )
                        }
                    } label: {
                        Label(
                            currentMessage.isStarred ? "Retirer le drapeau" : "Ajouter un drapeau",
                            systemImage: currentMessage.isStarred ? "flag.slash" : "flag"
                        )
                    }

                    Button {
                        Task {
                            await vm.performMessageAction(
                                messageIds: [currentMessage.id],
                                action: "toggle_pin",
                                toast: currentMessage.isPinned ? "Courrier désépinglé" : "Courrier épinglé"
                            )
                        }
                    } label: {
                        Label(
                            currentMessage.isPinned ? "Désépingler" : "Épingler en haut",
                            systemImage: currentMessage.isPinned ? "pin.slash" : "pin"
                        )
                    }

                    Button {
                        isShowingMoveFolderSheet = true
                    } label: {
                        Label("Déplacer vers un dossier…", systemImage: "folder")
                    }

                    Button {
                        Task {
                            await vm.performMessageAction(
                                messageIds: [currentMessage.id],
                                action: "spam",
                                toast: "Déplacé dans Indésirables"
                            )
                            vm.closeMessage()
                        }
                    } label: {
                        Label("Déplacer dans Indésirables", systemImage: "exclamationmark.shield")
                    }

                    Divider()

                    Button(role: .destructive) {
                        Task {
                            await vm.performMessageAction(
                                messageIds: [currentMessage.id],
                                action: "trash",
                                toast: "Déplacé dans la Corbeille"
                            )
                            vm.closeMessage()
                        }
                    } label: {
                        Label("Supprimer le courrier", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $isShowingMoveFolderSheet) {
            moveToFolderPickerSheet
        }
        .gesture(
            DragGesture(minimumDistance: 24, coordinateSpace: .local)
                .onEnded { value in
                    if value.startLocation.x < 44 && value.translation.width > 70 && abs(value.translation.height) < 90 {
                        vm.closeMessage()
                    }
                }
        )
        .task {
            await vm.openMessageAndLoadThread(message)
        }
    }

    // MARK: - 1. En-tête Expéditeur / Destinataire Style Apple Mail

    private var classicSenderHeaderSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VipleMailAvatarView(
                    name: currentMessage.senderName,
                    email: currentMessage.senderEmail,
                    avatarUrl: vm.resolveAvatarUrl(for: currentMessage.senderEmail, explicitUrl: currentMessage.senderAvatarUrl),
                    size: 42,
                    isVip: currentMessage.isVipSender
                )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(currentMessage.senderName.isEmpty ? currentMessage.senderEmail : currentMessage.senderName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(VipleMailPalette.ink)
                            .lineLimit(1)

                        if currentMessage.shouldShowVerifiedSenderBadge {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(VipleMailPalette.primary)
                                .accessibilityLabel("Expéditeur officiel vérifié")
                        }

                        if currentMessage.isVipSender {
                            Image(systemName: "star.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(VipleMailPalette.vipGold)
                        }

                        Spacer(minLength: 6)

                        Text(currentMessage.formattedRelativeDate)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(VipleMailPalette.inkMuted)
                    }

                    if let verifiedOrg = currentMessage.effectiveVerifiedOrganization {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 10.5))
                            Text("Vérifiée : \(verifiedOrg)")
                                .font(.system(size: 11.5, weight: .semibold))
                        }
                        .foregroundStyle(VipleMailPalette.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2.5)
                        .background(
                            Capsule()
                                .fill(VipleMailPalette.primary.opacity(0.10))
                        )
                    }

                    HStack(alignment: .center, spacing: 6) {
                        Text(recipientSummaryLabel)
                            .font(.system(size: 13.5))
                            .foregroundStyle(VipleMailPalette.inkSecondary)
                            .lineLimit(1)

                        if !currentMessage.ccEmail.isEmpty {
                            Text("• Cc")
                                .font(.system(size: 12.5))
                                .foregroundStyle(VipleMailPalette.inkMuted)
                        }

                        Spacer(minLength: 6)

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showFullHeaders.toggle()
                            }
                        } label: {
                            Text(showFullHeaders ? "Masquer" : "Détails")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(VipleMailPalette.primary)
                        }
                    }

                    // Ligne compacte « Sécurité » toujours lisible sous le destinataire
                    securitySummaryInlineRow
                }
            }

            if showFullHeaders {
                VStack(alignment: .leading, spacing: 6) {
                    rfcHeaderRow(label: "De :", value: "\(currentMessage.senderName) <\(currentMessage.senderEmail)>")
                    if let verifiedOrg = currentMessage.effectiveVerifiedOrganization {
                        rfcHeaderRow(label: "Entité :", value: "Vérifiée : \(verifiedOrg)")
                    }
                    rfcHeaderRow(label: "À :", value: currentMessage.recipientEmail)
                    if !currentMessage.ccEmail.isEmpty {
                        rfcHeaderRow(label: "Cc :", value: currentMessage.ccEmail)
                    }
                    rfcHeaderRow(label: "Date :", value: currentMessage.formattedFullDate)
                    rfcHeaderRow(label: "Dossier :", value: "\(currentMessage.folder) • \(currentMessage.formattedSize)")
                    rfcSecurityHeaderRow
                }
                .font(.system(size: 12.5))
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(VipleMailPalette.surfaceSubtle.opacity(0.75))
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private var securitySummaryInlineRow: some View {
        HStack(spacing: 4) {
            Image(systemName: currentMessage.isTransportUnencrypted == true ? "lock.open.fill" : "lock.fill")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(
                    currentMessage.isTransportUnencrypted == true
                        ? VipleMailPalette.danger
                        : (currentMessage.effectiveIsMailRteSecurity ? VipleMailPalette.primary : VipleMailPalette.inkMuted)
                )

            Text("Sécurité : \(currentMessage.effectiveEncryptionLabel)")
                .font(.system(size: 12, weight: currentMessage.effectiveIsMailRteSecurity ? .semibold : .regular))
                .foregroundStyle(
                    currentMessage.isTransportUnencrypted == true
                        ? VipleMailPalette.danger
                        : (currentMessage.effectiveIsMailRteSecurity ? VipleMailPalette.primary : VipleMailPalette.inkMuted)
                )
                .lineLimit(1)

            if currentMessage.effectiveIsMailRteSecurity {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(VipleMailPalette.primary)
                    .accessibilityLabel("Chiffrement Cenelis MailRTE vérifié")
            }
        }
        .padding(.top, 1)
    }

    private var rfcSecurityHeaderRow: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("Sécurité :")
                .foregroundStyle(VipleMailPalette.inkMuted)
                .frame(width: 68, alignment: .trailing)

            HStack(spacing: 5) {
                Text(currentMessage.effectiveEncryptionLabel)
                    .fontWeight(currentMessage.effectiveIsMailRteSecurity ? .semibold : .regular)
                    .foregroundStyle(
                        currentMessage.isTransportUnencrypted == true
                            ? VipleMailPalette.danger
                            : (currentMessage.effectiveIsMailRteSecurity ? VipleMailPalette.primary : VipleMailPalette.ink)
                    )
                    .textSelection(.enabled)

                if currentMessage.effectiveIsMailRteSecurity {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(VipleMailPalette.primary)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private func rfcHeaderRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .foregroundStyle(VipleMailPalette.inkMuted)
                .frame(width: 68, alignment: .trailing)
            Text(value)
                .foregroundStyle(VipleMailPalette.ink)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }

    // MARK: - 2. Ligne Objet Classique + Drapeau / Priorité

    private var classicSubjectHeaderSection: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text(currentMessage.subject)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(VipleMailPalette.ink)
                    .textSelection(.enabled)

                if currentMessage.isHighPriority || currentMessage.folder.lowercased() != "inbox" {
                    HStack(spacing: 8) {
                        if currentMessage.isHighPriority {
                            Label("Importance haute", systemImage: "exclamationmark.circle.fill")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(VipleMailPalette.danger)
                        }
                        if currentMessage.folder.lowercased() != "inbox" {
                            Text(currentMessage.folder)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(VipleMailPalette.inkSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .fill(VipleMailPalette.surfaceSubtle)
                                )
                        }
                    }
                }
            }

            Spacer(minLength: 6)

            Button {
                Task {
                    await vm.performMessageAction(
                        messageIds: [currentMessage.id],
                        action: "toggle_star",
                        toast: currentMessage.isStarred ? "Drapeau retiré" : "Drapeau ajouté"
                    )
                }
            } label: {
                Image(systemName: currentMessage.isStarred ? "flag.fill" : "flag")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(currentMessage.isStarred ? Color.orange : VipleMailPalette.inkMuted)
                    .padding(4)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    // MARK: - 3. Bandeau Pièces Jointes Classique

    private func classicAttachmentsSection(_ list: [VipleMailAttachment]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(list) { att in
                HStack(spacing: 10) {
                    Image(systemName: att.iconName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(VipleMailPalette.primary)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(VipleMailPalette.primary.opacity(0.10))
                        )

                    VStack(alignment: .leading, spacing: 1) {
                        Text(att.fileName)
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundStyle(VipleMailPalette.ink)
                            .lineLimit(1)
                        Text(att.formattedSize)
                            .font(.system(size: 11.5))
                            .foregroundStyle(VipleMailPalette.inkMuted)
                    }

                    Spacer()

                    if let url = URL(string: att.url), !att.url.isEmpty {
                        Link(destination: url) {
                            Label("Ouvrir", systemImage: "arrow.down.circle")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(VipleMailPalette.primary)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(VipleMailPalette.border, lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - 4. Corps du Courrier Pleine Largeur (Zéro Carte / Zéro Bulle)

    private func hasRichHTML(_ raw: String) -> Bool {
        let lower = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !lower.isEmpty else { return false }
        return lower.contains("<html") || lower.contains("<body") || lower.contains("<div") || lower.contains("<table") || lower.contains("<p") || lower.contains("<img") || lower.contains("<a ") || lower.contains("<ul") || lower.contains("<ol") || lower.contains("<blockquote") || lower.contains("<h1") || lower.contains("<h2") || lower.contains("<h3") || lower.contains("<style") || lower.contains("<span") || lower.contains("<font") || lower.contains("<center") || lower.contains("<section") || lower.contains("<article") || lower.contains("<br")
    }

    private func classicEmailBodySection(_ msg: VipleMailMessage) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if msg.requiresCenelisPin == true && msg.bodyHtml.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                MailRteCenelisPinGateView(
                    message: msg,
                    mailboxEmail: vm.primaryHostedEmail.isEmpty ? vm.currentEmail : vm.primaryHostedEmail,
                    cid: vm.currentCid
                ) { unlocked in
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) {
                        htmlContentHeight = 260
                        pinUnlockedMessage = unlocked
                    }
                }
            } else {
            #if canImport(WebKit) && canImport(UIKit)
            if hasRichHTML(msg.bodyHtml) {
                if colorScheme == .dark {
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if vm.adaptHtmlEmailsInDarkMode {
                                    forceOriginalLightEmail.toggle()
                                } else {
                                    vm.adaptHtmlEmailsInDarkMode = true
                                    forceOriginalLightEmail = false
                                }
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: effectiveRenderHtmlDark ? "sun.max.fill" : "moon.stars.fill")
                                    .font(.system(size: 10.5, weight: .bold))
                                Text(effectiveRenderHtmlDark ? "Voir l'original clair" : "Adapter au mode sombre")
                                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(VipleMailPalette.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(VipleMailPalette.surfaceSubtle)
                                    .overlay(
                                        Capsule()
                                            .stroke(VipleMailPalette.border, lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                if colorScheme == .dark && !effectiveRenderHtmlDark {
                    VipleMailHTMLWebView(
                        htmlBody: msg.bodyHtml,
                        renderDark: false,
                        dynamicHeight: $htmlContentHeight
                    )
                    .frame(height: htmlContentHeight)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(VipleMailPalette.border, lineWidth: 1)
                    )
                } else {
                    VipleMailHTMLWebView(
                        htmlBody: msg.bodyHtml,
                        renderDark: effectiveRenderHtmlDark,
                        dynamicHeight: $htmlContentHeight
                    )
                    .frame(height: htmlContentHeight)
                }
            } else {
                Text(msg.plainBodyText)
                    .font(.system(size: 15.5))
                    .foregroundStyle(VipleMailPalette.ink)
                    .lineSpacing(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            #else
            Text(msg.plainBodyText)
                .font(.system(size: 15.5))
                .foregroundStyle(VipleMailPalette.ink)
                .lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            #endif
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
    }

    // MARK: - 5. Historique Replié des Courriers Précédents (Style Citations Mail)

    private var classicQuotedThreadSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showPreviousThreadEmails.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: showPreviousThreadEmails ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(VipleMailPalette.inkMuted)
                    Text("\(previousEmailsInThread.count) courrier(s) précédent(s) dans cet objet")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(VipleMailPalette.surfaceSubtle.opacity(0.55))
            }
            .buttonStyle(.plain)

            if showPreviousThreadEmails {
                ForEach(previousEmailsInThread) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        Divider()
                        HStack {
                            Text("De : \(item.senderName) <\(item.senderEmail)>")
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(VipleMailPalette.inkSecondary)
                                .lineLimit(1)
                            Spacer()
                            Text(item.formattedFullDate)
                                .font(.system(size: 11.5))
                                .foregroundStyle(VipleMailPalette.inkMuted)
                        }
                        Text(item.plainBodyText)
                            .font(.system(size: 14))
                            .foregroundStyle(VipleMailPalette.inkSecondary)
                            .lineSpacing(4)
                            .padding(.leading, 10)
                            .overlay(alignment: .leading) {
                                Rectangle()
                                    .fill(VipleMailPalette.border)
                                    .frame(width: 2.5)
                            }
                            .textSelection(.enabled)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
    }

    // MARK: - 6. Barre d'Actions Inférieure Classique Style Apple Mail

    private var classicMailBottomToolbar: some View {
        HStack {
            Button(role: .destructive) {
                Task {
                    await vm.performMessageAction(
                        messageIds: [currentMessage.id],
                        action: "trash",
                        toast: "Déplacé dans la Corbeille"
                    )
                    vm.closeMessage()
                }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(VipleMailPalette.primary)
                    .frame(width: 44, height: 38)
            }
            .accessibilityLabel("Supprimer")

            Spacer()

            Button {
                Task {
                    await vm.performMessageAction(
                        messageIds: [currentMessage.id],
                        action: "archive",
                        toast: "Courrier archivé"
                    )
                    vm.closeMessage()
                }
            } label: {
                Image(systemName: "archivebox")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(VipleMailPalette.primary)
                    .frame(width: 44, height: 38)
            }
            .accessibilityLabel("Archiver")

            Spacer()

            Button {
                isShowingMoveFolderSheet = true
            } label: {
                Image(systemName: "folder")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(VipleMailPalette.primary)
                    .frame(width: 44, height: 38)
            }
            .accessibilityLabel("Déplacer vers un dossier")

            Spacer()

            Menu {
                Button {
                    // Répond toujours en mode Mail classique (même si l'expéditeur est @viplemail.fr)
                    vm.presentComposer(.reply(currentMessage))
                } label: {
                    Label("Répondre", systemImage: "arrowshape.turn.up.left")
                }

                Button {
                    vm.presentComposer(.replyAll(currentMessage))
                } label: {
                    Label("Répondre à tous", systemImage: "arrowshape.turn.up.left.2")
                }

                Button {
                    vm.presentComposer(.forward(currentMessage))
                } label: {
                    Label("Transférer", systemImage: "arrowshape.turn.up.right")
                }
            } label: {
                Image(systemName: "arrowshape.turn.up.left")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(VipleMailPalette.primary)
                    .frame(width: 44, height: 38)
            }
            .accessibilityLabel("Répondre ou transférer")

            Spacer()

            Button {
                vm.presentComposer(.newMail())
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(VipleMailPalette.primary)
                    .frame(width: 44, height: 38)
            }
            .accessibilityLabel("Nouveau message")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 6)
        .background(
            VipleMailPalette.surfaceSubtle.opacity(0.92)
                .overlay(alignment: .top) {
                    Divider()
                }
        )
    }

    private var moveToFolderPickerSheet: some View {
        NavigationStack {
            List {
                ForEach(vm.folders.filter { $0.id != "Starred" && $0.id != "Flagged" && $0.id != "Unread" && $0.id != "VIP" }) { folder in
                    Button {
                        isShowingMoveFolderSheet = false
                        Task {
                            await vm.performMessageAction(
                                messageIds: [currentMessage.id],
                                action: "move",
                                targetFolder: folder.id,
                                toast: "Déplacé vers \(folder.name)"
                            )
                            vm.closeMessage()
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: folder.icon)
                                .foregroundStyle(VipleMailPalette.colorFromHex(folder.colorHex))
                                .frame(width: 28)
                            Text(folder.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(VipleMailPalette.ink)
                            Spacer()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(VipleMailPalette.background)
            .navigationTitle("Déplacer vers…")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        isShowingMoveFolderSheet = false
                    }
                }
            }
        }
        .preferredColorScheme(vm.preferredColorSchemeOverride)
    }
}
