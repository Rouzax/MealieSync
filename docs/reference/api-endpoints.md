# API Endpoints

MealieSync uses the following Mealie v2.x REST API endpoints:

| Function   | Methods             | Endpoint                       |
| ---------- | ------------------- | ------------------------------ |
| Foods      | GET/POST/PUT/DELETE | `/api/foods`                   |
| Units      | GET/POST/PUT/DELETE | `/api/units`                   |
| Labels     | GET/POST/PUT/DELETE | `/api/groups/labels`           |
| Categories | GET/POST/PUT/DELETE | `/api/organizers/categories`   |
| Tags       | GET/POST/PUT/DELETE | `/api/organizers/tags`         |
| Tools      | GET/POST/PUT/DELETE | `/api/organizers/tools`        |
| Households | GET                 | `/api/groups/households`       |
| Recipes    | GET                 | `/api/recipes`                 |

Recipes are read-only. MealieSync queries them during Mirror operations to check whether foods scheduled for deletion are used in any recipes (protected items are not deleted).

All API calls go through `Invoke-MealieRequest`, which handles authentication headers, UTF-8 encoding, and error parsing.
