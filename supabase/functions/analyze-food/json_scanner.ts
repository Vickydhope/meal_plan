/**
 * Scans the accumulated response text for JSON values that have just
 * closed, tracking bracket/quote depth rather than doing a full parse on
 * every delta (the overall JSON document is still open).
 */
export class IncrementalJsonScanner {
  #mealNameSent = false;
  #itemsSeen = 0;

  /**
   * Pulls out the `meal_name` string value and any newly complete objects
   * inside the `items` array from the accumulated text, invoking
   * onMealName/onItem at most once each per new value found.
   */
  scan(
    buffer: string,
    onMealName: (name: string) => void,
    onItem: (item: Record<string, unknown>) => void,
  ) {
    if (!this.#mealNameSent) {
      const match = /"meal_name"\s*:\s*"((?:[^"\\]|\\.)*)"/.exec(buffer);
      if (match) {
        this.#mealNameSent = true;
        onMealName(JSON.parse(`"${match[1]}"`));
      }
    }

    const itemsStart = buffer.indexOf('"items"');
    if (itemsStart === -1) return;
    const arrayStart = buffer.indexOf("[", itemsStart);
    if (arrayStart === -1) return;

    let depth = 0;
    let inString = false;
    let escaped = false;
    let objectStart = -1;
    let objectsSeen = 0;

    for (let i = arrayStart; i < buffer.length; i++) {
      const char = buffer[i];

      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (char === "\\") {
          escaped = true;
        } else if (char === '"') {
          inString = false;
        }
        continue;
      }

      if (char === '"') {
        inString = true;
      } else if (char === "{") {
        // depth is 0 here for an item's own opening brace (we're directly
        // inside the items array, one level in) — check before incrementing.
        if (depth === 0 && objectStart === -1) objectStart = i;
        depth++;
      } else if (char === "}") {
        depth--;
        // Symmetric with the open-brace check above: back to depth 0 means
        // this closed an item object, not some field nested inside one.
        if (depth === 0 && objectStart !== -1) {
          objectsSeen++;
          if (objectsSeen > this.#itemsSeen) {
            try {
              const item = JSON.parse(buffer.slice(objectStart, i + 1));
              this.#itemsSeen = objectsSeen;
              onItem(item);
            } catch {
              // Incomplete/malformed — wait for more text.
            }
          }
          objectStart = -1;
        }
      } else if (char === "]" && depth === 0) {
        break;
      }
    }
  }
}
