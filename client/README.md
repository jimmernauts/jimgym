# JimGym - Workout Tracking Application

JimGym is a web application built with Gleam and Lustre that helps you track your gym workouts. It allows you to create workout sessions, add exercises with sets, reps, and weights, and view your workout history.

## Features

- Create new workout sessions
- Add exercises with customizable sets, reps, and weights
- Remove exercises from current session
- View past workout sessions
- Responsive web interface with Tailwind CSS styling

## Technology Stack

- **Gleam** - The programming language
- **Lustre** - Web framework for building interactive web applications (v4.6.4)
- **Modem** - For routing
- **Rada** - For date handling
- **Tailwind CSS** - For styling
- **Bun** - JavaScript runtime
- **Vite** - Frontend build tool

## Project Structure

```
client/
├── src/
│   └── app.gleam       # Main application logic
├── README.md           # Project overview
├── gleam.toml          # Gleam project configuration
└── index.html          # HTML entry point
```

## Getting Started

### Prerequisites

- Gleam (latest version)
- Bun (latest version)
- Node.js and npm (for JavaScript dependencies)

### Installation

1. Clone the repository
2. Install dependencies:

```bash
cd client
gleam deps download
bun install
```

### Running the Development Server

To run the development server:

```bash
bun vite dev
```

This will start a Vite development server that:
- Serves your application
- Provides hot module replacement
- Automatically reloads when you make changes to your code

You can also use the Lustre development tools for an alternative development experience:

```bash
gleam run -m lustre_dev_tools
```

### Building for Production

To build the application for production:

```bash
bun vite build
```

This will create optimized production assets in the `dist` directory.

## Application Architecture

JimGym follows the Lustre architecture pattern, which is inspired by Elm:

### Model

The application state is represented by the `Model` type, which includes:
- Current route
- Current gym session
- Past sessions history
- Form state for adding exercises

### Messages

User interactions are represented by the `Msg` type, which includes actions like:
- Adding/removing exercises
- Starting new sessions
- Form input changes
- Route changes

### Update Function

The `update` function handles state changes based on messages, returning a new model and any side effects.

### View Functions

The UI is divided into three main components:
1. `view_exercise_form` - For adding new exercises
2. `view_current_session` - Displays the active workout session
3. `view_past_sessions` - Shows previous workout history

## UI and Styling

The application uses Tailwind CSS for styling with a responsive design:

- Card-based layout with shadows and rounded corners
- Responsive grid for form inputs
- Color-coded buttons (green for positive actions, red for removal)
- Proper spacing and typography hierarchy

## Deployment

After building the application with `bun vite build`, you can deploy the contents of the `dist` directory to any static hosting service such as:

- Netlify
- Vercel
- GitHub Pages
- AWS S3
- Firebase Hosting

## Development Workflow

1. Make changes to the Gleam code in `src/app.gleam`
2. The development server will automatically recompile and reload
3. Test your changes in the browser
4. Build for production when ready to deploy

## Extending the Application

### Adding New Features

To add new features to the application:

1. Update the `Msg` type with any new message types
2. Add corresponding handlers in the `update` function
3. Create or modify view functions as needed
4. Update the main `view` function to include your new UI components

### Adding Exercise Categories

To categorize exercises (e.g., chest, legs, back):

1. Add a category field to the `Exercise` type
2. Update the form to include category selection
3. Modify the view to group exercises by category

### Adding Statistics and Analytics

To add workout statistics:

1. Create new view functions for displaying statistics
2. Add data processing functions to calculate metrics
3. Update the model to store historical data

## Troubleshooting

### Common Issues

- If the development server fails to start, ensure all dependencies are installed
- If styles are not applying correctly, check that Tailwind CSS is properly configured
- If routes are not working, verify the Modem configuration

## Resources

- [Gleam Documentation](https://gleam.run/documentation/)
- [Lustre Documentation](https://hexdocs.pm/lustre)
- [Tailwind CSS Documentation](https://tailwindcss.com/docs)
- [Vite Documentation](https://vitejs.dev/guide/)

## License

This project is open source and available under the MIT License.
