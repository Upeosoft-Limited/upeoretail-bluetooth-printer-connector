/**
 * UpeoRetail → native printer bridge helper.
 *
 * Drop this into your Next.js app (e.g. lib/printReceipt.js) and call
 * printReceipt(receipt) when you want to print. Inside the UpeoRetail Print
 * Android app, window.UpeoRetailPrinter is injected and the receipt is printed
 * on the paired Bluetooth thermal printer. In a normal browser it falls back
 * to an alert so staff know to use the app.
 *
 * `receipt` shape (all numbers may be number or numeric string):
 * {
 *   businessName, receiptTitle, branch, city, phone, email, pin,
 *   invoiceNo, customer, date,
 *   items: [{ name, qty, price, total, tax }],
 *   subtotal, discount, vat, total, paid, change,
 *   paymentMethod, footer, qrData
 * }
 */
export function printReceipt(receipt) {
  const message = {
    type: "PRINT_RECEIPT",
    payload: receipt,
  };

  if (
    typeof window !== "undefined" &&
    window.UpeoRetailPrinter &&
    typeof window.UpeoRetailPrinter.postMessage === "function"
  ) {
    window.UpeoRetailPrinter.postMessage(JSON.stringify(message));
    return true;
  }

  alert("Printer bridge not available. Please use the UpeoRetail Android app.");
  return false;
}

/** True when running inside the UpeoRetail Print Android wrapper. */
export function isNativePrinterAvailable() {
  return (
    typeof window !== "undefined" &&
    !!window.UpeoRetailPrinter &&
    typeof window.UpeoRetailPrinter.postMessage === "function"
  );
}
