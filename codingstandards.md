# CODING_STANDARDS.md

## GENERAL
- Clean, readable code
- Meaningful variable names
- No commented junk
- No dead code

## FLUTTER
- Feature-based folders
- Stateless widgets preferred
- Use const constructors
- Separate UI & logic
- No business logic in widgets

## NODE.JS
- MVC architecture
- Controllers = logic only
- Routes = routing only
- Models = schema only
- Services for business logic

## DATABASE
- camelCase fields
- Use references properly
- Avoid deep nesting

## API
- RESTful naming
- Proper HTTP status codes
- Consistent response format:
  {
    success: boolean,
    message: string,
    data: object
  }

## COMMITS (If Applicable)
- feat: new feature
- fix: bug fix
- refactor: code improvement
- docs: documentation

## COMMENTS
- Explain WHY, not WHAT
- Keep concise
